import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Helper to get current user ID
  static String? get userId {
    try {
      return _client.auth.currentUser?.id;
    } catch (e) {
      // Handle session refresh errors gracefully
      print('Warning: Could not get user ID due to session error: $e');
      return null;
    }
  }

  // Helper to check if session is valid
  static bool _isSessionValid() {
    try {
      final session = _client.auth.currentSession;
      return session != null && session.user != null;
    } catch (e) {
      // Session refresh failed - likely corrupted session
      print('Warning: Session validation failed: $e');
      return false;
    }
  }

  // In SupabaseService
  static Future<void> deleteCategory(String name) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      await _client
          .from('categories')
          .delete()
          .eq('user_id', userId!)
          .eq('name', name);
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }

  // Categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    if (!_isSessionValid() || userId == null) return [];

    try {
      final response = await _client
          .from('categories')
          .select()
          .eq('user_id', userId!)
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching categories: $e');
      // Check if it's a session refresh error
      if (e.toString().contains('oauth_client_id') ||
          e.toString().contains('AuthRetryableFetchException')) {
        print('Warning: Session refresh failed, clearing invalid session');
        try {
          await _client.auth.signOut();
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> saveCategories(
      List<Map<String, dynamic>> categories,
      ) async {
    if (!_isSessionValid() || userId == null) return;
    for (final category in categories) {
      await addCategory(category);
    }
  }

  static Future<void> addCategory(Map<String, dynamic> category) async {
    if (!_isSessionValid() || userId == null) return;

    try {
      final categoryName = category['name'] ?? '';
      if (categoryName.isNotEmpty) {
        final existing = await _client
            .from('categories')
            .select('id')
            .eq('user_id', userId!)
            .eq('name', categoryName)
            .maybeSingle();

        if (existing != null) return;
      }

      await _client.from('categories').insert({
        'user_id': userId!,
        'name': categoryName,
        'color': category['color'] ?? '#FF6B6B',
        'icon': category['icon'] ?? 'category',
      });
    } catch (e) {
      print('Error adding category: $e');
      rethrow;
    }
  }

  // Transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    if (!_isSessionValid() || userId == null) return [];

    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId!)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching transactions: $e');
      rethrow;
    }
  }

  static Future<void> saveTransactions(
      List<Map<String, dynamic>> transactions,
      ) async {
    if (!_isSessionValid() || userId == null) return;
    for (final transaction in transactions) {
      await addTransaction(transaction);
    }
  }

  static Future<void> addTransaction(Map<String, dynamic> transaction) async {
    if (!_isSessionValid() || userId == null) return;

    try {
      final transactionId = (transaction['transactionId'] ?? transaction['transaction_id'] ?? '').toString();
      if (transactionId.isNotEmpty) {
        final existing = await _client
            .from('transactions')
            .select('id')
            .eq('user_id', userId!)
            .eq('transaction_id', transactionId)
            .maybeSingle();

        if (existing != null) return;
      }

      final cleanTransaction = {
        'user_id': userId!,
        'transaction_id': transactionId,
        'description': transaction['description'] ?? '',
        'amount': transaction['amount'] ?? 0.0,
        'type': transaction['type'] ?? 'Debit',
        'date': transaction['date'] ?? DateTime.now().toIso8601String(),
        'category': transaction['category'] ?? '',
        'status': transaction['status'] ?? 'Completed',
      };

      if (transaction.containsKey('isSplit')) cleanTransaction['is_split'] = transaction['isSplit'];
      if (transaction.containsKey('splitCount')) cleanTransaction['split_count'] = transaction['splitCount'];

      await _client.from('transactions').insert(cleanTransaction);
    } catch (e) {
      print('Error adding transaction: $e');
      rethrow;
    }
  }

  static Future<void> updateTransaction(
      String transactionId,
      Map<String, dynamic> updates,
      ) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      // Map camelCase to snake_case for Supabase if necessary
      final mappedUpdates = Map<String, dynamic>.from(updates);
      if (mappedUpdates.containsKey('transactionId')) {
        mappedUpdates['transaction_id'] = mappedUpdates.remove('transactionId');
      }

      await _client
          .from('transactions')
          .update(mappedUpdates)
          .eq('user_id', userId!)
          .eq('transaction_id', transactionId);
    } catch (e) {
      print('Error updating transaction: $e');
      rethrow;
    }
  }

  static Future<void> deleteTransaction(String transactionId) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      await _client
          .from('transactions')
          .delete()
          .eq('user_id', userId!)
          .eq('transaction_id', transactionId);
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }

  // Budgets
  static Future<Map<String, double>> getBudgets() async {
    if (!_isSessionValid() || userId == null) return {};
    try {
      final response = await _client.from('budgets').select().eq('user_id', userId!);
      final budgets = <String, double>{};
      for (final row in response) {
        budgets[row['category']] = (row['amount'] as num).toDouble();
      }
      return budgets;
    } catch (e) {
      print('Error fetching budgets: $e');
      rethrow;
    }
  }

  static Future<void> saveBudgets(Map<String, double> budgets) async {
    if (!_isSessionValid() || userId == null) return;
    for (final entry in budgets.entries) {
      await addBudget(entry.key, entry.value);
    }
  }

  static Future<void> addBudget(String category, double amount) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      await _client.from('budgets').upsert({
        'user_id': userId!,
        'category': category,
        'amount': amount,
      }, onConflict: 'user_id, category');
    } catch (e) {
      print('Error adding/updating budget: $e');
      rethrow;
    }
  }

  // OWO Entries
  static Future<List<Map<String, dynamic>>> getOwoEntries() async {
    if (!_isSessionValid() || userId == null) return [];
    try {
      final response = await _client
          .from('owo_entries')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching OWO entries: $e');
      rethrow;
    }
  }

  static Future<void> saveOwoEntries(List<Map<String, dynamic>> entries) async {
    if (!_isSessionValid() || userId == null) return;
    for (final entry in entries) {
      await addOwoEntry(entry);
    }
  }

  static Future<void> addOwoEntry(Map<String, dynamic> entry) async {
    if (!_isSessionValid() || userId == null) return;

    try {
      final owoId = (entry['owoId'] ?? entry['owo_id'] ?? entry['id'] ?? '').toString();
      if (owoId.isNotEmpty) {
        final existing = await _client
            .from('owo_entries')
            .select('id')
            .eq('user_id', userId!)
            .eq('owo_id', owoId)
            .maybeSingle();

        if (existing != null) return;
      }

      await _client.from('owo_entries').insert({
        'user_id': userId!,
        'owo_id': owoId,
        'counterparty': entry['counterparty'] ?? '',
        'direction': entry['direction'] ?? 'owe',
        'amount': entry['amount'] ?? 0.0,
        'note': entry['note'] ?? '',
        'created_at': entry['createdAt'] ?? entry['created_at'] ?? DateTime.now().toIso8601String(),
        'due_date': entry['dueDate'] ?? entry['due_date'],
        'settled': entry['settled'] ?? false,
      });
    } catch (e) {
      print('Error adding OWO entry: $e');
      rethrow;
    }
  }

  static Future<void> updateOwoEntry(Map<String, dynamic> entry) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      final owoId = (entry['owo_id'] ?? entry['owoId'] ?? entry['id'] ?? '').toString();
      if (owoId.isEmpty) return;

      final updates = {
        'counterparty': entry['counterparty'],
        'direction': entry['direction'],
        'amount': entry['amount'],
        'note': entry['note'],
        'due_date': entry['dueDate'] ?? entry['due_date'],
        'settled': entry['settled'],
      };
      updates.removeWhere((key, value) => value == null);

      await _client
          .from('owo_entries')
          .update(updates)
          .eq('user_id', userId!)
          .eq('owo_id', owoId);
    } catch (e) {
      print('Error updating OWO entry: $e');
      rethrow;
    }
  }

  static Future<void> deleteOwoEntry(String owoId) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      await _client
          .from('owo_entries')
          .delete()
          .eq('user_id', userId!)
          .eq('owo_id', owoId);
    } catch (e) {
      print('Error deleting OWO entry: $e');
      rethrow;
    }
  }

  // Initial Balance
  static Future<double?> getInitialBalance() async {
    if (!_isSessionValid() || userId == null) return null;
    try {
      final response = await _client
          .from('user_settings')
          .select('initial_balance')
          .eq('user_id', userId!)
          .maybeSingle();

      if (response != null && response['initial_balance'] != null) {
        return (response['initial_balance'] as num).toDouble();
      }
      return null;
    } catch (e) {
      // PGRST205 means the 'user_settings' table doesn't exist in Supabase.
      // We catch this specifically to avoid noisy errors.
      if (e.toString().contains('PGRST205')) {
        return null;
      }
      print('Error fetching initial balance: $e');
      return null;
    }
  }

  static Future<void> setInitialBalance(double balance) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      await _client.from('user_settings').upsert({
        'user_id': userId!,
        'initial_balance': balance,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (e.toString().contains('PGRST205')) {
        print('Cloud sync skipped: user_settings table does not exist in Supabase.');
        return;
      }
      print('Error saving initial balance: $e');
      rethrow;
    }
  }

  // Trips Sync
  static Future<List<Map<String, dynamic>>> getTrips() async {
    if (!_isSessionValid() || userId == null) return [];
    try {
      final response = await _client
          .from('trips')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('42P01')) {
        return [];
      }
      print('Error fetching trips: $e');
      return [];
    }
  }

  static Future<void> addTrip(Map<String, dynamic> tripData) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      final data = {
        'user_id': userId!,
        'trip_id': tripData['tripId'],
        'name': tripData['name'],
        'categories': tripData['categories'],
        'created_at': tripData['createdAt'],
        'start_date': tripData['startDate'],
        'end_date': tripData['endDate'],
        'description': tripData['description'],
        'budget': tripData['budget'],
        'category_budgets': tripData['categoryBudgets'],
      };
      // NOTE: trip_id is the PRIMARY KEY on the trips table (see schema),
      // so the conflict target must be exactly 'trip_id'. Using
      // 'user_id, trip_id' here throws 42P10 (no matching unique
      // constraint) because no such composite constraint exists.
      await _client.from('trips').upsert(data, onConflict: 'trip_id');
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('42P01')) {
        print('Cloud sync skipped: trips table does not exist in Supabase.');
        return;
      }
      print('Error adding/updating trip: $e');
      rethrow;
    }
  }

  static Future<void> deleteTrip(String tripId) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      await _client
          .from('trips')
          .delete()
          .eq('user_id', userId!)
          .eq('trip_id', tripId);
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('42P01')) {
        return;
      }
      print('Error deleting trip: $e');
      rethrow;
    }
  }

  // Trip Transactions Sync
  static Future<List<Map<String, dynamic>>> getTripTransactions(String tripId) async {
    if (!_isSessionValid() || userId == null) return [];
    try {
      final response = await _client
          .from('trip_transactions')
          .select()
          .eq('user_id', userId!)
          .eq('trip_id', tripId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('42P01')) {
        return [];
      }
      print('Error fetching trip transactions: $e');
      return [];
    }
  }

  static Future<void> saveTripTransactions(String tripId, List<Map<String, dynamic>> transactions) async {
    if (!_isSessionValid() || userId == null) return;
    try {
      await _client
          .from('trip_transactions')
          .delete()
          .eq('user_id', userId!)
          .eq('trip_id', tripId);

      if (transactions.isEmpty) return;

      final dataList = transactions.map((t) => {
        'user_id': userId!,
        'trip_id': tripId,
        'transaction_id': (t['transactionId'] ?? t['transaction_id'] ?? '').toString(),
        'description': t['description'] ?? '',
        'amount': t['amount'] ?? 0.0,
        'type': t['type'] ?? 'Debit',
        'date': t['date'] ?? DateTime.now().toIso8601String(),
        'category': t['category'] ?? '',
        'status': t['status'] ?? 'Completed',
      }).toList();

      await _client.from('trip_transactions').insert(dataList);
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('42P01')) {
        print('Cloud sync skipped: trip_transactions table does not exist in Supabase.');
        return;
      }
      print('Error saving trip transactions: $e');
      rethrow;
    }
  }
}