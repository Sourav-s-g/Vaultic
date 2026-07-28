import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/trip.dart';

class TripStorageService {
  static const String _tripsKey = 'trips';
  static const String _tripTransactionsKey = 'trip_transactions';

  // Save trips
  static Future<void> saveTrips(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = trips.map((trip) => trip.toMap()).toList();
    await prefs.setString(_tripsKey, jsonEncode(tripsJson));
  }

  // Get trips
  static Future<List<Trip>> getTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = prefs.getString(_tripsKey);
    if (tripsJson == null) return [];

    final List<dynamic> tripsList = jsonDecode(tripsJson);
    return tripsList.map((tripMap) => Trip.fromMap(tripMap)).toList();
  }

  // Add trip
  static Future<void> addTrip(Trip trip) async {
    final trips = await getTrips();
    trips.add(trip);
    await saveTrips(trips);
  }

  // Delete trip
  static Future<void> deleteTrip(String tripId) async {
    final trips = await getTrips();
    trips.removeWhere((trip) => trip.tripId == tripId);
    await saveTrips(trips);

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
  }

  // Get trip transactions
  static Future<List<Map<String, dynamic>>> getTripTransactions(
    String tripId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_tripTransactionsKey}_$tripId';
    final transactionsJson = prefs.getString(key);
    if (transactionsJson == null) return [];

    final List<dynamic> transactionsList = jsonDecode(transactionsJson);
    return transactionsList.cast<Map<String, dynamic>>();
  }

  // Add trip transaction
  static Future<void> addTripTransaction(
    String tripId,
    Map<String, dynamic> transaction,
  ) async {
    final transactions = await getTripTransactions(tripId);
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
  }

  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (key) => key == _tripsKey || key.startsWith('${_tripTransactionsKey}_'),
    );
    await Future.wait(keys.map(prefs.remove));
  }
}
