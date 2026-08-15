import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/trip.dart';
import 'supabase_service.dart';

class TripStorageService {
  static const String _tripsKey = 'trips';
  static const String _tripTransactionsKey = 'trip_transactions';

  // Save trips locally and try syncing to cloud database
  static Future<void> saveTrips(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = trips.map((trip) => trip.toMap()).toList();
    await prefs.setString(_tripsKey, jsonEncode(tripsJson));

    // Cloud sync
    for (final trip in trips) {
      try {
        await SupabaseService.addTrip(trip.toMap());
      } catch (e) {
        print('Trip cloud sync failed: $e');
      }
    }
  }

  // Get trips with database integration (offline-first)
  static Future<List<Trip>> getTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = prefs.getString(_tripsKey);
    List<Trip> localTrips = [];
    if (tripsJson != null) {
      try {
        final List<dynamic> tripsList = jsonDecode(tripsJson);
        localTrips = tripsList.map((tripMap) => Trip.fromMap(tripMap)).toList();
      } catch (_) {}
    }

    // Try fetching from Supabase
    try {
      final remoteTripsData = await SupabaseService.getTrips();
      if (remoteTripsData.isNotEmpty) {
        final remoteTrips = remoteTripsData.map((m) => Trip.fromMap(m)).toList();

        // Merge local & remote trips (remote wins on conflict)
        final Map<String, Trip> merged = {for (var t in localTrips) t.tripId: t};
        for (final remoteTrip in remoteTrips) {
          merged[remoteTrip.tripId] = remoteTrip;
        }

        final result = merged.values.toList();

        // Update local cache
        final tripsJsonMerged = result.map((trip) => trip.toMap()).toList();
        await prefs.setString(_tripsKey, jsonEncode(tripsJsonMerged));

        return result;
      }
    } catch (e) {
      print('Failed to pull trips from database: $e');
    }

    return localTrips;
  }

  // Add trip
  static Future<void> addTrip(Trip trip) async {
    final trips = await getTrips();
    trips.removeWhere((t) => t.tripId == trip.tripId);
    trips.add(trip);
    await saveTrips(trips);
  }

  // Delete trip
  static Future<void> deleteTrip(String tripId) async {
    final trips = await getTrips();
    trips.removeWhere((trip) => trip.tripId == tripId);

    final prefs = await SharedPreferences.getInstance();
    final tripsJson = trips.map((trip) => trip.toMap()).toList();
    await prefs.setString(_tripsKey, jsonEncode(tripsJson));

    // Delete in cloud
    try {
      await SupabaseService.deleteTrip(tripId);
    } catch (_) {}

    // Also delete trip transactions
    await deleteTripTransactions(tripId);
  }

  // Get trip by ID
  static Future<Trip?> getTripById(String tripId) async {
    final trips = await getTrips();
    try {
      return trips.firstWhere((trip) => trip.tripId == tripId);
    } catch (e) {
      return null;
    }
  }

  // Save trip transactions
  static Future<void> saveTripTransactions(
      String tripId,
      List<Map<String, dynamic>> transactions,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_tripTransactionsKey}_$tripId';
    await prefs.setString(key, jsonEncode(transactions));

    // Cloud sync
    try {
      await SupabaseService.saveTripTransactions(tripId, transactions);
    } catch (e) {
      print('Trip transactions cloud sync failed: $e');
    }
  }

  // Get trip transactions
  static Future<List<Map<String, dynamic>>> getTripTransactions(
      String tripId,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_tripTransactionsKey}_$tripId';
    final transactionsJson = prefs.getString(key);
    List<Map<String, dynamic>> localTxns = [];
    if (transactionsJson != null) {
      try {
        final List<dynamic> transactionsList = jsonDecode(transactionsJson);
        localTxns = transactionsList.cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    // Try fetching from database
    try {
      final remoteTxns = await SupabaseService.getTripTransactions(tripId);
      if (remoteTxns.isNotEmpty) {
        // Simple merge: remote wins for matching transaction IDs
        final Map<String, Map<String, dynamic>> merged = {
          for (var t in localTxns) (t['transactionId'] ?? t['transaction_id'] ?? '').toString(): t
        };
        for (final remoteTxn in remoteTxns) {
          final id = (remoteTxn['transactionId'] ?? remoteTxn['transaction_id'] ?? '').toString();
          if (id.isNotEmpty) {
            merged[id] = remoteTxn;
          }
        }

        final result = merged.values.toList();
        await prefs.setString(key, jsonEncode(result));
        return result;
      }
    } catch (e) {
      print('Failed to pull trip transactions from database: $e');
    }

    return localTxns;
  }

  // Add trip transaction
  static Future<void> addTripTransaction(
      String tripId,
      Map<String, dynamic> transaction,
      ) async {
    final transactions = await getTripTransactions(tripId);
    transactions.removeWhere((t) =>
    (t['transactionId'] ?? t['transaction_id'] ?? '').toString() ==
        (transaction['transactionId'] ?? transaction['transaction_id'] ?? '').toString());
    transactions.add(transaction);
    await saveTripTransactions(tripId, transactions);
  }

  // Delete trip transaction
  static Future<void> deleteTripTransaction(
      String tripId,
      String transactionId,
      ) async {
    final transactions = await getTripTransactions(tripId);
    transactions.removeWhere(
          (t) =>
      (t['transactionId'] ?? '').toString() == transactionId ||
          (t['transaction_id'] ?? '').toString() == transactionId,
    );
    await saveTripTransactions(tripId, transactions);
  }

  // Delete all trip transactions
  static Future<void> deleteTripTransactions(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_tripTransactionsKey}_$tripId';
    await prefs.remove(key);

    try {
      await SupabaseService.saveTripTransactions(tripId, []);
    } catch (_) {}
  }

  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
          (key) => key == _tripsKey || key.startsWith('${_tripTransactionsKey}_'),
    );
    await Future.wait(keys.map(prefs.remove));
  }
}