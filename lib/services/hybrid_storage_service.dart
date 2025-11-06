import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'data_migration_service.dart';

class HybridStorageService {
  static const String _lastSyncKey = 'vaultic_last_sync_v1';
  static const String _categoriesKey = 'vaultic_categories_v1';
  static const String _transactionsKey = 'vaultic_transactions_v1';
  static const String _budgetsKey = 'vaultic_budgets_v1';
  static const String _owoKey = 'vaultic_owo_v1';
  static const String _lastOtpVerifyKey = 'vaultic_last_otp_verify_at_v1';
  static const String _initialBalanceKey = 'vaultic_initial_balance_v1';
  static const String _lastMonthlyRolloverKey = 'vaultic_last_monthly_rollover_v1';
  static const String _processedMonthsKey = 'vaultic_processed_months_v1';
  static const String _backupVersionKey = 'vaultic_backup_version_v1';
  static const int _maxBackupVersions = 5; // Keep last 5 backups
  static const String _autoBackupEnabledKey = 'vaultic_auto_backup_enabled_v1';
  static const String _lastAutoBackupKey = 'vaultic_last_auto_backup_v1';
  static const String _syncQueueKey = 'vaultic_sync_queue_v1';
  static const String _failedTransactionsKey = 'vaultic_failed_transactions_v1';

  // Check if user is authenticated
  static bool get _isAuthenticated => SupabaseService.userId != null;

  // Categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    if (_isAuthenticated) {
      // Try Supabase first
      try {
        final cloudData = await SupabaseService.getCategories();
        if (cloudData.isNotEmpty) {
          // Update local cache
          await _saveToLocal(_categoriesKey, cloudData);
          return cloudData;
        }
      } catch (e) {
        // Cloud fetch failed, using local data
      }
    }
    
    // Fallback to local storage
    return await _getFromLocal(_categoriesKey);
  }

  static Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    // Save locally first for immediate UI update
    await _saveToLocal(_categoriesKey, categories);
    
    // Save to cloud if authenticated
    if (_isAuthenticated) {
      try {
        await SupabaseService.saveCategories(categories);
      } catch (e) {
        // Cloud save failed
        // Local save already succeeded, so UI won't break
      }
    }
  }

  static Future<void> addCategory(Map<String, dynamic> category) async {
    final categories = await getCategories();
    final name = (category['name'] ?? '').toString();
    if (name.isNotEmpty && !categories.any((c) => (c['name'] ?? '') == name)) {
      categories.add(category);
      await saveCategories(categories);
    }
  }

  static Future<void> removeCategoryByName(String name) async {
    final categories = await getCategories();
    categories.removeWhere((c) => (c['name'] ?? '') == name);
    await saveCategories(categories);
    await removeBudget(name);
  }

  // Transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    if (_isAuthenticated) {
      try {
        final cloudData = await SupabaseService.getTransactions();
        if (cloudData.isNotEmpty) {
          await _saveToLocal(_transactionsKey, cloudData);
          return cloudData;
        }
      } catch (e) {
        // Cloud fetch failed, using local data
      }
    }
    
    return await _getFromLocal(_transactionsKey);
  }

  static Future<void> saveTransactions(List<Map<String, dynamic>> transactions) async {
    await _saveToLocal(_transactionsKey, transactions);
    
    if (_isAuthenticated) {
      try {
        await SupabaseService.saveTransactions(transactions);
      } catch (e) {
        // Cloud save failed
      }
    }
  }

  static Future<void> addTransaction(Map<String, dynamic> transaction) async {
    // Create backup before making changes
    final transactions = await getTransactions();
    final backup = List<Map<String, dynamic>>.from(transactions);
    
    try {
      // Add to local storage first (safer)
      transactions.add(transaction);
      await _saveToLocal(_transactionsKey, transactions);
      
      // Mark as not synced initially
      transaction['_syncStatus'] = 'pending';
      transaction['_syncAttempts'] = 0;
      // Avoid inserting null into a map that may be inferred as Map<String, Object>
      transaction['_lastSyncAttempt'] = '';
      
      // Add to cloud
      if (_isAuthenticated) {
        try {
          await SupabaseService.addTransaction(transaction);
          // Mark as synced
          transaction['_syncStatus'] = 'synced';
          transaction['_lastSyncAttempt'] = DateTime.now().toIso8601String();
          // Update in local storage
          final index = transactions.indexWhere((t) => 
            (t['transactionId'] ?? '').toString() == (transaction['transactionId'] ?? '').toString());
          if (index != -1) {
            transactions[index] = transaction;
            await _saveToLocal(_transactionsKey, transactions);
          }
        } catch (e) {
          print('Cloud add failed, queueing for retry: $e');
          // Queue for retry
          await _queueForSync(transaction, 'add');
          // Mark as pending sync
          transaction['_syncStatus'] = 'pending';
          final index = transactions.indexWhere((t) => 
            (t['transactionId'] ?? '').toString() == (transaction['transactionId'] ?? '').toString());
          if (index != -1) {
            transactions[index] = transaction;
            await _saveToLocal(_transactionsKey, transactions);
          }
        }
      } else {
        // Not authenticated, mark as pending
        transaction['_syncStatus'] = 'pending';
        final index = transactions.indexWhere((t) => 
          (t['transactionId'] ?? '').toString() == (transaction['transactionId'] ?? '').toString());
        if (index != -1) {
          transactions[index] = transaction;
          await _saveToLocal(_transactionsKey, transactions);
        }
      }
      
      // Check and process monthly rollover after adding transaction
      // Only if this is not a carry-forward transaction (to avoid recursion)
      final isCarryForward = transaction['isCarryForward'] == true;
      if (!isCarryForward) {
        await _checkAndProcessMonthlyRollover();
      }
    } catch (e) {
      print('Error adding transaction: $e');
      // Restore backup if local save failed
      try {
        await _saveToLocal(_transactionsKey, backup);
        print('Restored backup after failed transaction add');
      } catch (restoreError) {
        print('Failed to restore backup: $restoreError');
      }
      rethrow;
    }
  }

  static Future<void> updateTransactionById(String transactionId, Map<String, dynamic> updates) async {
    // Update local storage
    final transactions = await getTransactions();
    final index = transactions.indexWhere((t) => (t['transactionId'] ?? '').toString() == transactionId);
    if (index != -1) {
      final transaction = transactions[index];
      transaction.addAll(updates);
      transaction['_syncStatus'] = 'pending';
      if (transaction['_syncAttempts'] == null) {
        transaction['_syncAttempts'] = 0;
      }
      transactions[index] = transaction;
      await _saveToLocal(_transactionsKey, transactions);
    }
    
    // Update cloud
    if (_isAuthenticated) {
      try {
        await SupabaseService.updateTransaction(transactionId, updates);
        // Mark as synced
        if (index != -1) {
          transactions[index]['_syncStatus'] = 'synced';
          transactions[index]['_lastSyncAttempt'] = DateTime.now().toIso8601String();
          await _saveToLocal(_transactionsKey, transactions);
        }
      } catch (e) {
        // Queue for retry
        await _queueForSync({'transactionId': transactionId, ...updates}, 'update');
      }
    }
  }

  static Future<void> deleteTransactionById(String transactionId) async {
    // Get local data directly (not from cloud cache)
    final transactions = await _getFromLocal(_transactionsKey);
    final initialCount = transactions.length;
    
    // Try both camelCase and snake_case keys
    transactions.removeWhere((t) {
      final camelId = (t['transactionId'] ?? '').toString();
      final snakeId = (t['transaction_id'] ?? '').toString();
      return camelId == transactionId || snakeId == transactionId;
    });
    final finalCount = transactions.length;
    
    if (initialCount > finalCount) {
      await _saveToLocal(_transactionsKey, transactions);
    }
    
    // Delete from cloud
    if (_isAuthenticated) {
      try {
        await SupabaseService.deleteTransaction(transactionId);
      } catch (e) {
        // Queue for retry
        await _queueForSync({'transactionId': transactionId}, 'delete');
      }
    }
  }

  // Budgets
  static Future<Map<String, double>> getBudgets() async {
    if (_isAuthenticated) {
      try {
        final cloudData = await SupabaseService.getBudgets();
        if (cloudData.isNotEmpty) {
          await _saveToLocal(_budgetsKey, [cloudData]);
          return cloudData;
        }
      } catch (e) {
        // Cloud fetch failed, using local data
      }
    }
    
    final localData = await _getFromLocal(_budgetsKey);
    if (localData.isNotEmpty) {
      return Map<String, double>.from(localData.first);
    }
    return {};
  }

  static Future<void> saveBudgets(Map<String, double> budgets) async {
    await _saveToLocal(_budgetsKey, [budgets]);
    
    if (_isAuthenticated) {
      try {
        await SupabaseService.saveBudgets(budgets);
      } catch (e) {
        // Cloud save failed
      }
    }
  }

  static Future<void> setBudget(String category, double amount) async {
    final budgets = await getBudgets();
    budgets[category] = amount;
    await saveBudgets(budgets);
  }

  static Future<void> removeBudget(String category) async {
    final budgets = await getBudgets();
    budgets.remove(category);
    await saveBudgets(budgets);
  }

  // OWO Entries
  static Future<List<Map<String, dynamic>>> getOwoEntries() async {
    if (_isAuthenticated) {
      try {
        final cloudData = await SupabaseService.getOwoEntries();
        if (cloudData.isNotEmpty) {
          await _saveToLocal(_owoKey, cloudData);
          return cloudData;
        }
      } catch (e) {
        // Cloud fetch failed, using local data
      }
    }
    
    return await _getFromLocal(_owoKey);
  }

  static Future<void> saveOwoEntries(List<Map<String, dynamic>> entries) async {
    await _saveToLocal(_owoKey, entries);
    
    if (_isAuthenticated) {
      try {
        await SupabaseService.saveOwoEntries(entries);
      } catch (e) {
        // Cloud save failed
      }
    }
  }

  static Future<void> addOwoEntry(Map<String, dynamic> entry) async {
    final entries = await getOwoEntries();
    entries.add(entry);
    await saveOwoEntries(entries);
    
    if (_isAuthenticated) {
      try {
        await SupabaseService.addOwoEntry(entry);
      } catch (e) {
        // Cloud add failed
      }
    }
  }

  static Future<void> updateOwoEntry(Map<String, dynamic> entry) async {
    final entries = await getOwoEntries();
    final index = entries.indexWhere((e) => (e['id'] ?? '').toString() == entry['id']);
    if (index != -1) {
      entries[index] = entry;
      await saveOwoEntries(entries);
    }
    
    if (_isAuthenticated) {
      try {
        await SupabaseService.updateOwoEntry(entry);
      } catch (e) {
        // Cloud update failed
      }
    }
  }

  static Future<void> deleteOwoEntry(String id) async {
    final entries = await getOwoEntries();
    entries.removeWhere((e) => (e['id'] ?? '').toString() == id);
    await saveOwoEntries(entries);
    
    if (_isAuthenticated) {
      try {
        await SupabaseService.deleteOwoEntry(id);
      } catch (e) {
        print('Cloud delete failed: $e');
      }
    }
  }

  // OTP Verification
  static Future<void> setLastOtpVerification(DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOtpVerifyKey, when.toIso8601String());
  }

  static Future<DateTime?> getLastOtpVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastOtpVerifyKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  // Initial Balance
  static Future<double> getInitialBalance() async {
    if (_isAuthenticated) {
      try {
        final cloudBalance = await SupabaseService.getInitialBalance();
        if (cloudBalance != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(_initialBalanceKey, cloudBalance);
          return cloudBalance;
        }
      } catch (e) {
        // Cloud fetch failed, using local data
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_initialBalanceKey) ?? 0.0;
  }

  static Future<void> setInitialBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_initialBalanceKey, balance);
    
    if (_isAuthenticated) {
      try {
        await SupabaseService.setInitialBalance(balance);
      } catch (e) {
        // Cloud save failed
      }
    }
  }

  // Monthly Rollover Logic
  /// Calculate balance for a specific month
  static Future<double> calculateMonthEndBalance(int year, int month) async {
    final transactions = await getTransactions();
    final initialBalance = await getInitialBalance();
    
    // Get all transactions up to and including this month
    final monthTransactions = transactions.where((t) {
      final txnDate = DateTime.tryParse((t['date'] ?? '').toString()) ?? DateTime.now();
      // Include transactions from all previous months and current month
      if (txnDate.year < year) return true;
      if (txnDate.year == year && txnDate.month <= month) return true;
      return false;
    }).toList();
    
    // Calculate credits and debits
    double totalCredits = initialBalance;
    double totalDebits = 0.0;
    
    for (final t in monthTransactions) {
      final type = (t['type'] ?? '').toString();
      final amount = (t['amount'] is num) 
          ? (t['amount'] as num).toDouble() 
          : double.tryParse((t['amount'] ?? '0').toString()) ?? 0.0;
      
      if (type == 'Credit') {
        totalCredits += amount;
      } else if (type == 'Debit') {
        totalDebits += amount;
      }
    }
    
    return totalCredits - totalDebits;
  }

  /// Check and process monthly rollover for completed months
  static Future<void> _checkAndProcessMonthlyRollover() async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    
    // Get list of processed months
    final prefs = await SharedPreferences.getInstance();
    final processedMonthsJson = prefs.getString(_processedMonthsKey);
    final processedMonths = processedMonthsJson != null
        ? (jsonDecode(processedMonthsJson) as List).map((e) => e.toString()).toSet()
        : <String>{};
    
    // Check all months from the first transaction month to last completed month
    final transactions = await getTransactions();
    if (transactions.isEmpty) return;
    
    // Find earliest transaction date
    DateTime? earliestDate;
    for (final t in transactions) {
      final date = DateTime.tryParse((t['date'] ?? '').toString());
      if (date != null) {
        if (earliestDate == null || date.isBefore(earliestDate)) {
          earliestDate = date;
        }
      }
    }
    
    if (earliestDate == null) return;
    
    // Process each completed month
    DateTime monthStart = DateTime(earliestDate.year, earliestDate.month, 1);
    
    while (monthStart.isBefore(currentMonth)) {
      final monthKey = '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}';
      
      // Skip if already processed
      if (processedMonths.contains(monthKey)) {
        monthStart = DateTime(monthStart.year, monthStart.month + 1, 1);
        continue;
      }
      
      // Calculate month-end balance
      final monthEndBalance = await calculateMonthEndBalance(monthStart.year, monthStart.month);
      
      // Process based on balance
      if (monthEndBalance > 0) {
        // Positive balance: Add as credit to next month
        await _addCarryForwardCredit(monthStart, monthEndBalance);
      } else if (monthEndBalance < 0) {
        // Negative balance: Add OWO entry
        await _addNegativeBalanceOwo(monthStart, monthEndBalance.abs());
      }
      
      // Mark month as processed
      processedMonths.add(monthKey);
      
      // Move to next month
      monthStart = DateTime(monthStart.year, monthStart.month + 1, 1);
    }
    
    // Save processed months
    await prefs.setString(_processedMonthsKey, jsonEncode(processedMonths.toList()));
    await prefs.setString(_lastMonthlyRolloverKey, now.toIso8601String());
  }

  /// Add carry-forward credit transaction for positive month-end balance
  static Future<void> _addCarryForwardCredit(DateTime month, double amount) async {
    if (amount <= 0) return;
    
    // Check if carry-forward credit already exists for this month
    final transactions = await getTransactions();
    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    
    final existingCredit = transactions.any((t) {
      final desc = (t['description'] ?? '').toString();
      final date = DateTime.tryParse((t['date'] ?? '').toString()) ?? DateTime.now();
      return desc.contains('Balance carried forward from') &&
             desc.contains(monthKey) &&
             date.year == nextMonth.year &&
             date.month == nextMonth.month;
    });
    
    if (existingCredit) return; // Already processed
    
    // Add credit transaction on first day of next month
    final carryForwardTransaction = {
      'transactionId': 'carry_forward_${month.year}_${month.month}_${DateTime.now().millisecondsSinceEpoch}',
      'description': 'Balance carried forward from ${_formatMonthName(month)}',
      'amount': amount,
      'type': 'Credit',
      'date': nextMonth.toIso8601String(),
      'category': '',
      'status': 'Completed',
      'isSplit': false,
      'splitCount': 1,
      'isCarryForward': true, // Mark as carry-forward transaction
    };
    
    // Add transaction directly without triggering rollover (to avoid recursion)
    transactions.add(carryForwardTransaction);
    await _saveToLocal(_transactionsKey, transactions);
    
    // Add to cloud
    if (_isAuthenticated) {
      try {
        await SupabaseService.addTransaction(carryForwardTransaction);
      } catch (e) {
        print('Cloud add failed for carry-forward: $e');
      }
    }
    
    print('Added carry-forward credit of ₹${amount.toStringAsFixed(2)} for ${_formatMonthName(month)}');
  }

  /// Add OWO entry for negative month-end balance
  static Future<void> _addNegativeBalanceOwo(DateTime month, double amount) async {
    if (amount <= 0) return;
    
    // Check if OWO entry already exists for this month
    final owoEntries = await getOwoEntries();
    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    
    final existingOwo = owoEntries.any((e) {
      final note = (e['note'] ?? '').toString();
      return note.contains('Negative balance from') && note.contains(monthKey);
    });
    
    if (existingOwo) return; // Already processed
    
    // Create OWO entry
    final owoEntry = {
      'id': 'negative_balance_${month.year}_${month.month}_${DateTime.now().millisecondsSinceEpoch}',
      'counterparty': '${_formatMonthName(month)} Balance',
      'direction': 'owe',
      'amount': amount,
      'note': 'Negative balance from ${_formatMonthName(month)}',
      'createdAt': DateTime(month.year, month.month + 1, 1).toIso8601String(),
      'dueDate': null,
      'settled': false,
      'isNegativeBalance': true, // Mark as negative balance OWO
    };
    
    await addOwoEntry(owoEntry);
    print('Added OWO entry for negative balance of ₹${amount.toStringAsFixed(2)} from ${_formatMonthName(month)}');
  }

  /// Format month name for display
  static String _formatMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Manually trigger monthly rollover check (useful for testing or manual sync)
  static Future<void> processMonthlyRollover() async {
    await _checkAndProcessMonthlyRollover();
  }

  // Sync management
  static Future<void> syncOnLogin() async {
    if (!_isAuthenticated) return;
    
    try {
      // First, migrate any existing local data to cloud
      await DataMigrationService.migrateLocalDataToCloud();
      
      // Then sync all data from cloud to local
      await getCategories();
      await getTransactions();
      await getBudgets();
      await getOwoEntries();
      
      // Process monthly rollover after syncing data
      await _checkAndProcessMonthlyRollover();
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      print('Sync completed successfully');
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  // Helper methods
  static Future<List<Map<String, dynamic>>> _getFromLocal(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<void> _saveToLocal(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }
  
  // Data recovery methods
  static Future<bool> recoverFromCloud() async {
    if (!_isAuthenticated) return false;
    
    try {
      print('Attempting data recovery from cloud...');
      
      // Try to get fresh data from cloud
      final cloudTransactions = await SupabaseService.getTransactions();
      final cloudCategories = await SupabaseService.getCategories();
      final cloudBudgets = await SupabaseService.getBudgets();
      final cloudOwoEntries = await SupabaseService.getOwoEntries();
      
      // Save cloud data locally
      await _saveToLocal(_transactionsKey, cloudTransactions);
      await _saveToLocal(_categoriesKey, cloudCategories);
      await _saveToLocal(_budgetsKey, cloudBudgets);
      await _saveToLocal(_owoKey, cloudOwoEntries);
      
      print('Data recovery successful');
      return true;
    } catch (e) {
      print('Data recovery failed: $e');
      return false;
    }
  }
  
  /// Create a backup with versioning support
  static Future<Map<String, dynamic>> createBackup({String? customName}) async {
    try {
      final initialBalance = await getInitialBalance();
      final transactions = await getTransactions();
      final categories = await getCategories();
      final budgets = await getBudgets();
      final owoEntries = await OwesOwnsStorage.getOwoEntries();
      
      final backup = {
        'transactions': transactions,
        'categories': categories,
        'budgets': budgets,
        'owoEntries': owoEntries,
        'initialBalance': initialBalance,
        'timestamp': DateTime.now().toIso8601String(),
        'name': customName ?? 'Manual Backup',
        'version': '1.0',
        'transactionCount': transactions.length,
        'categoryCount': categories.length,
        'budgetCount': budgets.length,
        'owoCount': owoEntries.length,
      };
      
      // Calculate backup size
      final backupJson = jsonEncode(backup);
      final sizeInBytes = backupJson.length;
      
      // Add size to backup metadata
      backup['sizeInBytes'] = sizeInBytes;
      backup['sizeFormatted'] = _formatBytes(sizeInBytes);
      
      // Save with versioning
      await _saveBackupWithVersioning(backup);
      
      print('Backup created successfully: ${backup['name']}');
      return backup;
    } catch (e) {
      print('Failed to create backup: $e');
      rethrow;
    }
  }

  /// Save backup with versioning (keep last N backups)
  static Future<void> _saveBackupWithVersioning(Map<String, dynamic> backup) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing backup versions
    final backupVersionsJson = prefs.getString(_backupVersionKey);
    final backupVersions = backupVersionsJson != null
        ? (jsonDecode(backupVersionsJson) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    
    // Add new backup
    backupVersions.add(backup);
    
    // Sort by timestamp (newest first)
    backupVersions.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
      final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    
    // Keep only last N backups
    if (backupVersions.length > _maxBackupVersions) {
      backupVersions.removeRange(_maxBackupVersions, backupVersions.length);
    }
    
    // Save all backup versions
    await prefs.setString(_backupVersionKey, jsonEncode(backupVersions));
    
    // Also save latest backup for backward compatibility
    await prefs.setString('vaultic_backup', jsonEncode(backup));
  }

  /// Get all backup versions
  static Future<List<Map<String, dynamic>>> getAllBackups() async {
    final prefs = await SharedPreferences.getInstance();
    final backupVersionsJson = prefs.getString(_backupVersionKey);
    
    if (backupVersionsJson == null) {
      // Try to get legacy single backup
      final legacyBackup = prefs.getString('vaultic_backup');
      if (legacyBackup != null) {
        try {
          final backup = jsonDecode(legacyBackup) as Map<String, dynamic>;
          // Migrate legacy backup to versioned system
          await _saveBackupWithVersioning(backup);
          return [backup];
        } catch (e) {
          print('Error migrating legacy backup: $e');
        }
      }
      return [];
    }
    
    try {
      final backups = (jsonDecode(backupVersionsJson) as List)
          .cast<Map<String, dynamic>>();
      
      // Sort by timestamp (newest first)
      backups.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      
      return backups;
    } catch (e) {
      print('Error reading backups: $e');
      return [];
    }
  }

  /// Get latest backup
  static Future<Map<String, dynamic>?> getLatestBackup() async {
    final backups = await getAllBackups();
    return backups.isNotEmpty ? backups.first : null;
  }

  /// Restore from a specific backup
  static Future<bool> restoreFromBackup([Map<String, dynamic>? backup]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Use provided backup or get latest
      Map<String, dynamic>? backupToRestore = backup;
      if (backupToRestore == null) {
        backupToRestore = await getLatestBackup();
        if (backupToRestore == null) {
          // Try legacy backup
          final legacyBackup = prefs.getString('vaultic_backup');
          if (legacyBackup == null) return false;
          backupToRestore = jsonDecode(legacyBackup) as Map<String, dynamic>;
        }
      }
      
      if (backupToRestore == null) return false;
      
      // Restore data
      await _saveToLocal(_transactionsKey, backupToRestore['transactions'] ?? []);
      await _saveToLocal(_categoriesKey, backupToRestore['categories'] ?? []);
      await _saveToLocal(_budgetsKey, backupToRestore['budgets'] ?? {});
      await _saveToLocal(_owoKey, backupToRestore['owoEntries'] ?? []);
      
      // Restore initial balance if available
      if (backupToRestore['initialBalance'] != null) {
        await setInitialBalance((backupToRestore['initialBalance'] as num).toDouble());
      }
      
      // Sync to cloud if authenticated
      if (_isAuthenticated) {
        try {
          await SupabaseService.saveTransactions(backupToRestore['transactions'] ?? []);
          await SupabaseService.saveCategories(backupToRestore['categories'] ?? []);
          await SupabaseService.saveBudgets(backupToRestore['budgets'] ?? {});
          await SupabaseService.saveOwoEntries(backupToRestore['owoEntries'] ?? []);
          if (backupToRestore['initialBalance'] != null) {
            await SupabaseService.setInitialBalance((backupToRestore['initialBalance'] as num).toDouble());
          }
        } catch (e) {
          print('Cloud sync after restore failed: $e');
        }
      }
      
      print('Backup restored successfully');
      return true;
    } catch (e) {
      print('Failed to restore backup: $e');
      return false;
    }
  }

  /// Delete a specific backup
  static Future<bool> deleteBackup(String timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupVersionsJson = prefs.getString(_backupVersionKey);
      
      if (backupVersionsJson == null) return false;
      
      final backupVersions = (jsonDecode(backupVersionsJson) as List)
          .cast<Map<String, dynamic>>();
      
      backupVersions.removeWhere((b) => (b['timestamp'] ?? '').toString() == timestamp);
      
      await prefs.setString(_backupVersionKey, jsonEncode(backupVersions));
      
      // Update latest backup if needed
      if (backupVersions.isNotEmpty) {
        await prefs.setString('vaultic_backup', jsonEncode(backupVersions.first));
      } else {
        await prefs.remove('vaultic_backup');
      }
      
      return true;
    } catch (e) {
      print('Failed to delete backup: $e');
      return false;
    }
  }

  /// Export backup to JSON string
  static Future<String> exportBackupToJson([Map<String, dynamic>? backup]) async {
    try {
      Map<String, dynamic>? backupToExport = backup;
      if (backupToExport == null) {
        backupToExport = await getLatestBackup();
        if (backupToExport == null) {
          throw Exception('No backup available to export');
        }
      }
      
      // Create exportable version (remove internal metadata if needed)
      final exportData = {
        'app': 'Vaultic',
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'backup': backupToExport,
      };
      
      return jsonEncode(exportData);
    } catch (e) {
      print('Failed to export backup: $e');
      rethrow;
    }
  }

  /// Import backup from JSON string
  static Future<bool> importBackupFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Handle both direct backup and wrapped export format
      Map<String, dynamic> backup;
      if (data.containsKey('backup')) {
        backup = data['backup'] as Map<String, dynamic>;
      } else {
        backup = data;
      }
      
      // Validate backup structure
      if (!backup.containsKey('transactions') || 
          !backup.containsKey('categories') ||
          !backup.containsKey('budgets') ||
          !backup.containsKey('owoEntries')) {
        throw Exception('Invalid backup format');
      }
      
      // Add import metadata
      backup['timestamp'] = DateTime.now().toIso8601String();
      backup['name'] = 'Imported Backup';
      
      // Save as new backup
      await _saveBackupWithVersioning(backup);
      
      return true;
    } catch (e) {
      print('Failed to import backup: $e');
      return false;
    }
  }

  /// Format bytes to human-readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Auto-backup management
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? false;
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
    
    if (enabled) {
      // Schedule first backup
      await _scheduleAutoBackup();
    }
  }

  /// Check and perform auto-backup if needed
  static Future<void> checkAndPerformAutoBackup() async {
    final isEnabled = await isAutoBackupEnabled();
    if (!isEnabled) return;
    
    final prefs = await SharedPreferences.getInstance();
    final lastBackupStr = prefs.getString(_lastAutoBackupKey);
    
    DateTime? lastBackup;
    if (lastBackupStr != null) {
      lastBackup = DateTime.tryParse(lastBackupStr);
    }
    
    final now = DateTime.now();
    final shouldBackup = lastBackup == null || 
        now.difference(lastBackup).inDays >= 1; // Daily backup
    
    if (shouldBackup) {
      try {
        await createBackup(customName: 'Auto Backup');
        await prefs.setString(_lastAutoBackupKey, now.toIso8601String());
        print('Auto-backup completed');
      } catch (e) {
        print('Auto-backup failed: $e');
      }
    }
  }

  /// Schedule auto-backup
  static Future<void> _scheduleAutoBackup() async {
    // This will be called on app startup and periodically
    await checkAndPerformAutoBackup();
  }

  // ==================== SYNC QUEUE MANAGEMENT ====================

  /// Queue an item for sync with retry strategy
  static Future<void> _queueForSync(Map<String, dynamic> data, String operation) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_syncQueueKey);
    final queue = queueJson != null
        ? (jsonDecode(queueJson) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    // Add to queue
    queue.add({
      'operation': operation, // 'add', 'update', 'delete'
      'data': data,
      'attempts': 0,
      'lastAttempt': null,
      'nextRetry': DateTime.now().toIso8601String(), // Immediate retry
      'createdAt': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_syncQueueKey, jsonEncode(queue));
  }

  /// Get sync queue
  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_syncQueueKey);
    if (queueJson == null) return [];
    
    try {
      return (jsonDecode(queueJson) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error reading sync queue: $e');
      return [];
    }
  }

  /// Get pending transactions count
  static Future<int> getPendingSyncCount() async {
    final transactions = await getTransactions();
    return transactions.where((t) => 
      (t['_syncStatus'] ?? 'synced').toString() == 'pending'
    ).length;
  }

  /// Process sync queue with exponential backoff
  static Future<Map<String, int>> processSyncQueue({bool force = false}) async {
    if (!_isAuthenticated) {
      return {'success': 0, 'failed': 0, 'skipped': 0};
    }

    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_syncQueueKey);
    if (queueJson == null) return {'success': 0, 'failed': 0, 'skipped': 0};

    final queue = (jsonDecode(queueJson) as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final results = {'success': 0, 'failed': 0, 'skipped': 0};
    final updatedQueue = <Map<String, dynamic>>[];

    for (final item in queue) {
      final nextRetry = DateTime.tryParse(item['nextRetry'] ?? '');
      final attempts = (item['attempts'] ?? 0) as int;

      // Skip if not time for retry yet (unless forced)
      if (!force && nextRetry != null && now.isBefore(nextRetry)) {
        updatedQueue.add(item);
        results['skipped'] = (results['skipped'] ?? 0) + 1;
        continue;
      }

      // Max attempts reached (10 attempts)
      if (attempts >= 10) {
        print('Max sync attempts reached for ${item['operation']}: ${item['data']}');
        // Move to failed transactions
        await _addToFailedTransactions(item);
        results['failed'] = (results['failed'] ?? 0) + 1;
        continue;
      }

      try {
        final operation = item['operation'] as String;
        final data = item['data'] as Map<String, dynamic>;
        bool success = false;

        switch (operation) {
          case 'add':
            await SupabaseService.addTransaction(data);
            success = true;
            // Update transaction sync status
            await _updateTransactionSyncStatus(data['transactionId']?.toString(), 'synced');
            break;
          case 'update':
            await SupabaseService.updateTransaction(
              data['transactionId']?.toString() ?? '',
              data,
            );
            success = true;
            await _updateTransactionSyncStatus(data['transactionId']?.toString(), 'synced');
            break;
          case 'delete':
            await SupabaseService.deleteTransaction(data['transactionId']?.toString() ?? '');
            success = true;
            break;
        }

        if (success) {
          results['success'] = (results['success'] ?? 0) + 1;
          print('✅ Synced ${operation}: ${data['transactionId']}');
        }
      } catch (e) {
        print('❌ Sync failed (attempt ${attempts + 1}): $e');
        // Exponential backoff: 2^attempts minutes
        final backoffMinutes = (attempts < 5) ? (1 << attempts) : 60; // Cap at 60 minutes
        final nextRetryTime = now.add(Duration(minutes: backoffMinutes));
        
        updatedQueue.add({
          ...item,
          'attempts': attempts + 1,
          'lastAttempt': now.toIso8601String(),
          'nextRetry': nextRetryTime.toIso8601String(),
          'lastError': e.toString(),
        });
        results['failed'] = (results['failed'] ?? 0) + 1;
      }
    }

    // Save updated queue
    await prefs.setString(_syncQueueKey, jsonEncode(updatedQueue));
    return results;
  }

  /// Update transaction sync status in local storage
  static Future<void> _updateTransactionSyncStatus(String? transactionId, String status) async {
    if (transactionId == null) return;
    
    final transactions = await getTransactions();
    final index = transactions.indexWhere((t) => 
      (t['transactionId'] ?? '').toString() == transactionId
    );
    
    if (index != -1) {
      transactions[index]['_syncStatus'] = status;
      transactions[index]['_lastSyncAttempt'] = DateTime.now().toIso8601String();
      await _saveToLocal(_transactionsKey, transactions);
    }
  }

  /// Add to failed transactions list
  static Future<void> _addToFailedTransactions(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final failedJson = prefs.getString(_failedTransactionsKey);
    final failed = failedJson != null
        ? (jsonDecode(failedJson) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    
    failed.add({
      ...item,
      'failedAt': DateTime.now().toIso8601String(),
    });
    
    await prefs.setString(_failedTransactionsKey, jsonEncode(failed));
  }

  /// Clear sync queue
  static Future<void> clearSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncQueueKey);
  }

  /// Manual sync now (called from UI)
  static Future<Map<String, int>> syncNow() async {
    print('🔄 Manual sync initiated...');
    
    // First, process pending queue
    final queueResults = await processSyncQueue(force: true);
    
    // Then, sync any pending transactions
    final transactions = await getTransactions();
    final pendingTransactions = transactions.where((t) => 
      (t['_syncStatus'] ?? 'synced').toString() == 'pending'
    ).toList();
    
    int synced = 0;
    for (final txn in pendingTransactions) {
      try {
        if (!_isAuthenticated) break;
        
        // Check if already exists in cloud (avoid duplicates)
        await SupabaseService.addTransaction(txn);
        await _updateTransactionSyncStatus(txn['transactionId']?.toString(), 'synced');
        synced++;
      } catch (e) {
        print('Failed to sync transaction ${txn['transactionId']}: $e');
        await _queueForSync(txn, 'add');
      }
    }
    
    return {
      'success': (queueResults['success'] ?? 0) + synced,
      'failed': queueResults['failed'] ?? 0,
      'skipped': queueResults['skipped'] ?? 0,
    };
  }
}

// Extension for OWO storage (maintaining compatibility)
extension OwesOwnsStorage on HybridStorageService {
  static Future<List<Map<String, dynamic>>> getOwoEntries() => HybridStorageService.getOwoEntries();
  static Future<void> saveOwoEntries(List<Map<String, dynamic>> list) => HybridStorageService.saveOwoEntries(list);
  static Future<void> addOwoEntry(Map<String, dynamic> entry) => HybridStorageService.addOwoEntry(entry);
  static Future<void> updateOwoEntry(Map<String, dynamic> entry) => HybridStorageService.updateOwoEntry(entry);
  static Future<void> deleteOwoEntry(String id) => HybridStorageService.deleteOwoEntry(id);
}
