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
      // Check if it's a session refresh error
      if (e.toString().contains('oauth_client_id') || 
          e.toString().contains('AuthRetryableFetchException')) {
        print('Warning: Session refresh failed, clearing invalid session');
        try {
          await _client.auth.signOut();
        } catch (_) {
          // Ignore sign out errors
        }
      }
      print('Error fetching categories: $e');
      return [];
    }
  }

  static Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // SAFE APPROACH: Add categories individually instead of bulk delete+insert
      // This prevents data loss if any individual category fails
      
      for (final category in categories) {
        try {
          await addCategory(category);
        } catch (e) {
          print('Error adding individual category: $e');
          // Continue with other categories instead of failing completely
        }
      }
    } catch (e) {
      print('Error saving categories: $e');
    }
  }

  static Future<void> addCategory(Map<String, dynamic> category) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // Check if category already exists to prevent duplicates
      final categoryName = category['name'] ?? '';
      if (categoryName.isNotEmpty) {
        final existing = await _client
            .from('categories')
            .select('id')
            .eq('user_id', userId!)
            .eq('name', categoryName)
            .maybeSingle();
        
        if (existing != null) {
          print('Category already exists, skipping: $categoryName');
          return;
        }
      }
      
      await _client
          .from('categories')
          .insert({
            'user_id': userId!,
            'name': categoryName,
            'color': category['color'] ?? '#FF6B6B',
            'icon': category['icon'] ?? 'category',
          });
          
      print('Category added successfully');
    } catch (e) {
      print('Error adding category: $e');
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
      // Check if it's a session refresh error
      if (e.toString().contains('oauth_client_id') || 
          e.toString().contains('AuthRetryableFetchException')) {
        print('Warning: Session refresh failed, clearing invalid session');
        try {
          await _client.auth.signOut();
        } catch (_) {
          // Ignore sign out errors
        }
      }
      print('Error fetching transactions: $e');
      return [];
    }
  }

  static Future<void> saveTransactions(List<Map<String, dynamic>> transactions) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // SAFE APPROACH: Add transactions individually instead of bulk delete+insert
      // This prevents data loss if any individual transaction fails
      
      for (final transaction in transactions) {
        try {
          await addTransaction(transaction);
        } catch (e) {
          print('Error adding individual transaction: $e');
          // Continue with other transactions instead of failing completely
        }
      }
    } catch (e) {
      print('Error saving transactions: $e');
    }
  }

  static Future<void> addTransaction(Map<String, dynamic> transaction) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // Check if transaction already exists to prevent duplicates
      final transactionId = transaction['transactionId'] ?? '';
      if (transactionId.isNotEmpty) {
        final existing = await _client
            .from('transactions')
            .select('id')
            .eq('user_id', userId!)
            .eq('transaction_id', transactionId)
            .maybeSingle();
        
        if (existing != null) {
          print('Transaction already exists, skipping: $transactionId');
          return;
        }
      }
      
      // Create a clean transaction object with only the fields we know exist
      final cleanTransaction = {
        'user_id': userId!,
        'transaction_id': transaction['transactionId'] ?? '',
        'description': transaction['description'] ?? '',
        'amount': transaction['amount'] ?? 0.0,
        'type': transaction['type'] ?? 'Debit',
        'date': transaction['date'] ?? DateTime.now().toIso8601String(),
        'category': transaction['category'] ?? '',
        'status': transaction['status'] ?? 'Completed',
      };
      
      // Try to add optional fields if they exist
      if (transaction.containsKey('isSplit')) {
        cleanTransaction['is_split'] = transaction['isSplit'];
      }
      if (transaction.containsKey('splitCount')) {
        cleanTransaction['split_count'] = transaction['splitCount'];
      }
      
      await _client
          .from('transactions')
          .insert(cleanTransaction);
          
      print('Transaction added successfully');
    } catch (e) {
      print('Error adding transaction: $e');
      
      // If still failing, try with minimal fields only
      try {
        final minimalTransaction = {
          'user_id': userId!,
          'transaction_id': transaction['transactionId'] ?? '',
          'description': transaction['description'] ?? '',
          'amount': transaction['amount'] ?? 0.0,
          'type': transaction['type'] ?? 'Debit',
          'date': transaction['date'] ?? DateTime.now().toIso8601String(),
          'category': transaction['category'] ?? '',
          'status': transaction['status'] ?? 'Completed',
        };
        
        await _client
            .from('transactions')
            .insert(minimalTransaction);
            
        print('Transaction added with minimal schema');
      } catch (minimalError) {
        print('Minimal schema also failed: $minimalError');
        print('Please check your database schema and recreate the transactions table');
      }
    }
  }

  static Future<void> updateTransaction(String transactionId, Map<String, dynamic> updates) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      await _client
          .from('transactions')
          .update(updates)
          .eq('user_id', userId!)
          .eq('transaction_id', transactionId);
    } catch (e) {
      print('Error updating transaction: $e');
    }
  }

  static Future<void> deleteTransaction(String transactionId) async {
    if (!_isSessionValid() || userId == null) {
      print('Cannot delete transaction: user not authenticated');
      return;
    }
    
    print('Attempting to delete transaction from cloud: $transactionId');
    
    try {
      final result = await _client
          .from('transactions')
          .delete()
          .eq('user_id', userId!)
          .eq('transaction_id', transactionId);
      
      print('Cloud deletion result: $result');
    } catch (e) {
      print('Error deleting transaction from cloud: $e');
      // Don't rethrow - let local deletion succeed even if cloud fails
    }
  }

  // Budgets
  static Future<Map<String, double>> getBudgets() async {
    if (!_isSessionValid() || userId == null) return {};
    
    try {
      final response = await _client
          .from('budgets')
          .select()
          .eq('user_id', userId!);
      
      final budgets = <String, double>{};
      for (final row in response) {
        budgets[row['category']] = (row['amount'] as num).toDouble();
      }
      return budgets;
    } catch (e) {
      print('Error fetching budgets: $e');
      return {};
    }
  }

  static Future<void> saveBudgets(Map<String, double> budgets) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // SAFE APPROACH: Add budgets individually instead of bulk delete+insert
      // This prevents data loss if any individual budget fails
      
      for (final entry in budgets.entries) {
        try {
          await addBudget(entry.key, entry.value);
        } catch (e) {
          print('Error adding individual budget: $e');
          // Continue with other budgets instead of failing completely
        }
      }
    } catch (e) {
      print('Error saving budgets: $e');
    }
  }

  static Future<void> addBudget(String category, double amount) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // Check if budget already exists to prevent duplicates
      final existing = await _client
          .from('budgets')
          .select('id')
          .eq('user_id', userId!)
          .eq('category', category)
          .maybeSingle();
      
      if (existing != null) {
        // Update existing budget
        await _client
            .from('budgets')
            .update({'amount': amount})
            .eq('user_id', userId!)
            .eq('category', category);
        print('Budget updated for category: $category');
      } else {
        // Insert new budget
        await _client
            .from('budgets')
            .insert({
              'user_id': userId!,
              'category': category,
              'amount': amount,
            });
        print('Budget added for category: $category');
      }
    } catch (e) {
      print('Error adding budget: $e');
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
      return [];
    }
  }

  static Future<void> saveOwoEntries(List<Map<String, dynamic>> entries) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // SAFE APPROACH: Add OWO entries individually instead of bulk delete+insert
      // This prevents data loss if any individual entry fails
      
      for (final entry in entries) {
        try {
          await addOwoEntry(entry);
        } catch (e) {
          print('Error adding individual OWO entry: $e');
          // Continue with other entries instead of failing completely
        }
      }
    } catch (e) {
      print('Error saving OWO entries: $e');
    }
  }

  static Future<void> addOwoEntry(Map<String, dynamic> entry) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // Check if OWO entry already exists to prevent duplicates
      final owoId = entry['owoId'] ?? entry['owo_id'] ?? '';
      if (owoId.isNotEmpty) {
        final existing = await _client
            .from('owo_entries')
            .select('id')
            .eq('user_id', userId!)
            .eq('owo_id', owoId)
            .maybeSingle();
        
        if (existing != null) {
          print('OWO entry already exists, skipping: $owoId');
          return;
        }
      }
      
      await _client
          .from('owo_entries')
          .insert({
            ...entry,
            'user_id': userId!,
            'id': null,
          });
          
      print('OWO entry added successfully');
    } catch (e) {
      print('Error adding OWO entry: $e');
    }
  }

  static Future<void> updateOwoEntry(Map<String, dynamic> entry) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      await _client
          .from('owo_entries')
          .update(entry)
          .eq('user_id', userId!)
          .eq('owo_id', entry['owo_id']);
    } catch (e) {
      print('Error updating OWO entry: $e');
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
      // If the settings table doesn't exist, ignore quietly and treat as no balance set
      final msg = e.toString();
      if (msg.contains("PGRST205") || msg.contains("Could not find the table 'public.user_settings'")) {
        return null;
      }
      print('Error fetching initial balance: $e');
      return null;
    }
  }

  static Future<void> setInitialBalance(double balance) async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      await _client
          .from('user_settings')
          .upsert({
            'user_id': userId!,
            'initial_balance': balance,
            'updated_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      // If table missing, skip without noisy error
      final msg = e.toString();
      if (msg.contains("PGRST205") || msg.contains("Could not find the table 'public.user_settings'")) {
        return;
      }
      print('Error saving initial balance: $e');
    }
  }

  // Sync all data
  static Future<void> syncAllData() async {
    if (!_isSessionValid() || userId == null) return;
    
    try {
      // This will be called when user logs in to sync local data to cloud
      // Implementation depends on your sync strategy
      print('Syncing all data for user: $userId');
    } catch (e) {
      print('Error syncing data: $e');
    }
  }
}
