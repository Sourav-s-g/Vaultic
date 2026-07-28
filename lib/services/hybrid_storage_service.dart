import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class HybridStorageService {
  static const String _lastSyncKey = 'vaultic_last_sync_v1';
  static const String _categoriesKey = 'vaultic_categories_v1';
  static const String _transactionsKey = 'vaultic_transactions_v1';
  static const String _budgetsKey = 'vaultic_budgets_v1';
  static const String _owoKey = 'vaultic_owo_v1';
  static const String _initialBalanceKey = 'vaultic_initial_balance_v1';
  static const String _lastMonthlyRolloverKey =
      'vaultic_last_monthly_rollover_v1';
  static const String _processedMonthsKey = 'vaultic_processed_months_v1';
  static const String _backupVersionKey = 'vaultic_backup_version_v1';
  static const int _maxBackupVersions = 5;
  static const String _autoBackupEnabledKey = 'vaultic_auto_backup_enabled_v1';
  static const String _lastAutoBackupKey = 'vaultic_last_auto_backup_v1';
  static const String _syncQueueKey = 'vaultic_sync_queue_v1';
  static const String _failedTransactionsKey = 'vaultic_failed_transactions_v1';

  static bool get _isAuthenticated => SupabaseService.userId != null;

  static Future<List<Map<String, dynamic>>> getCategories() async {
    if (_isAuthenticated) {
      try {
        final cloudData = await SupabaseService.getCategories();
        await _saveToLocal(_categoriesKey, cloudData);
        return cloudData;
      } catch (_) {}
    }
    return await _getFromLocal(_categoriesKey);
  }

  static Future<void> saveCategories(
    List<Map<String, dynamic>> categories,
  ) async {
    await _saveToLocal(_categoriesKey, categories);
    if (_isAuthenticated) {
      try {
        await SupabaseService.saveCategories(categories);
      } catch (_) {}
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
    await _saveToLocal(_categoriesKey, categories);
    if (_isAuthenticated) {
      await SupabaseService.deleteCategory(name);
    }
    await removeBudget(name);
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    if (_isAuthenticated) {
      try {
        final cloudData = await SupabaseService.getTransactions();
        await _saveToLocal(_transactionsKey, cloudData);
        return cloudData;
      } catch (_) {}
    }
    return await _getFromLocal(_transactionsKey);
  }

  static Future<void> saveTransactions(
    List<Map<String, dynamic>> transactions,
  ) async {
    await _saveToLocal(_transactionsKey, transactions);
    if (_isAuthenticated) {
      try {
        await SupabaseService.saveTransactions(transactions);
      } catch (_) {}
    }
  }

  static Future<void> addTransaction(Map<String, dynamic> transaction) async {
    final transactions = await getTransactions();
    try {
      transactions.add(transaction);
      await _saveToLocal(_transactionsKey, transactions);

      transaction['_syncStatus'] = 'pending';
      transaction['_syncAttempts'] = 0;
      transaction['_lastSyncAttempt'] = '';

      if (_isAuthenticated) {
        try {
          await SupabaseService.addTransaction(transaction);
          transaction['_syncStatus'] = 'synced';
          transaction['_lastSyncAttempt'] = DateTime.now().toIso8601String();
          final idx = transactions.indexWhere(
            (t) =>
                (t['transactionId'] ?? '').toString() ==
                (transaction['transactionId'] ?? '').toString(),
          );
          if (idx != -1) {
            transactions[idx] = transaction;
            await _saveToLocal(_transactionsKey, transactions);
          }
        } catch (_) {
          await _queueForSync(transaction, 'add');
        }
      }

      final isCarryForward = transaction['isCarryForward'] == true;
      if (!isCarryForward) {
        await _checkAndProcessMonthlyRollover();
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateTransactionById(
    String transactionId,
    Map<String, dynamic> updates,
  ) async {
    final transactions = await getTransactions();
    final index = transactions.indexWhere(
      (t) => (t['transactionId'] ?? '').toString() == transactionId,
    );
    if (index != -1) {
      final transaction = transactions[index];
      transaction.addAll(updates);
      transaction['_syncStatus'] = 'pending';
      transactions[index] = transaction;
      await _saveToLocal(_transactionsKey, transactions);
    }

    if (_isAuthenticated) {
      try {
        await SupabaseService.updateTransaction(transactionId, updates);
        if (index != -1) {
          transactions[index]['_syncStatus'] = 'synced';
          transactions[index]['_lastSyncAttempt'] =
              DateTime.now().toIso8601String();
          await _saveToLocal(_transactionsKey, transactions);
        }
      } catch (_) {
        await _queueForSync({
          'transactionId': transactionId,
          ...updates,
        }, 'update');
      }
    }
  }

  static Future<void> deleteTransactionById(String transactionId) async {
    final transactions = await _getFromLocal(_transactionsKey);
    transactions.removeWhere(
      (t) =>
          (t['transactionId'] ?? '').toString() == transactionId ||
          (t['transaction_id'] ?? '').toString() == transactionId,
    );
    await _saveToLocal(_transactionsKey, transactions);

    if (_isAuthenticated) {
      try {
        await SupabaseService.deleteTransaction(transactionId);
      } catch (_) {
        await _queueForSync({'transactionId': transactionId}, 'delete');
      }
    }
  }

  static Future<Map<String, double>> getBudgets() async {
    if (_isAuthenticated) {
      try {
        final cloudData = await SupabaseService.getBudgets();
        await _saveToLocal(_budgetsKey, [cloudData]);
        return cloudData;
      } catch (_) {}
    }
    final localData = await _getFromLocal(_budgetsKey);
    if (localData.isNotEmpty) return Map<String, double>.from(localData.first);
    return {};
  }

  static Future<void> saveBudgets(Map<String, double> budgets) async {
    await _saveToLocal(_budgetsKey, [budgets]);
    if (_isAuthenticated) {
      try {
        await SupabaseService.saveBudgets(budgets);
      } catch (_) {}
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

  static Future<List<Map<String, dynamic>>> getOwoEntries() async {
    if (_isAuthenticated) {
      try {
        final cloudData = await SupabaseService.getOwoEntries();
        await _saveToLocal(_owoKey, cloudData);
        return cloudData;
      } catch (_) {}
    }
    return await _getFromLocal(_owoKey);
  }

  static Future<void> saveOwoEntries(List<Map<String, dynamic>> entries) async {
    await _saveToLocal(_owoKey, entries);
    if (_isAuthenticated) {
      try {
        await SupabaseService.saveOwoEntries(entries);
      } catch (_) {}
    }
  }

  static Future<void> addOwoEntry(Map<String, dynamic> entry) async {
    final entries = await getOwoEntries();
    entries.add(entry);
    await saveOwoEntries(entries);
    if (_isAuthenticated) {
      try {
        await SupabaseService.addOwoEntry(entry);
      } catch (_) {}
    }
  }

  static Future<void> updateOwoEntry(Map<String, dynamic> entry) async {
    final entries = await getOwoEntries();
    final index = entries.indexWhere(
      (e) => (e['id'] ?? '').toString() == entry['id'],
    );
    if (index != -1) {
      entries[index] = entry;
      await saveOwoEntries(entries);
    }
    if (_isAuthenticated) {
      try {
        await SupabaseService.updateOwoEntry(entry);
      } catch (_) {}
    }
  }

  static Future<void> deleteOwoEntry(String id) async {
    final entries = await getOwoEntries();
    entries.removeWhere((e) => (e['id'] ?? '').toString() == id);
    await saveOwoEntries(entries);
    if (_isAuthenticated) {
      try {
        await SupabaseService.deleteOwoEntry(id);
      } catch (_) {}
    }
  }

  static Future<double> getInitialBalance() async {
    if (_isAuthenticated) {
      try {
        final cloudBalance = await SupabaseService.getInitialBalance();
        if (cloudBalance != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(_initialBalanceKey, cloudBalance);
          return cloudBalance;
        }
        return 0.0;
      } catch (_) {}
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
      } catch (_) {}
    }
  }

  // ==================== CARRY FORWARD LOGIC ====================

  /// Calculates the balance at the end of a specific month.
  /// IMPORTANT: It ignores carry-forward entries to avoid double counting.
  static Future<double> calculateMonthEndBalance(int year, int month) async {
    final transactions = await getTransactions();
    final initialBalance = await getInitialBalance();

    final relevantTransactions = transactions.where((t) {
      final date =
          DateTime.tryParse((t['date'] ?? '').toString()) ?? DateTime.now();
      // Only sum non-rollover entries to calculate a fresh cumulative total
      if (t['isCarryForward'] == true ||
          (t['description'] ?? '').toString().contains(
            'Balance carried forward',
          )) {
        return false;
      }
      if (date.year < year) return true;
      if (date.year == year && date.month <= month) return true;
      return false;
    });

    double total = initialBalance;
    for (final t in relevantTransactions) {
      final amount =
          (t['amount'] is num)
              ? (t['amount'] as num).toDouble()
              : double.tryParse((t['amount'] ?? '0').toString()) ?? 0.0;
      if (t['type'] == 'Credit')
        total += amount;
      else
        total -= amount;
    }
    return total;
  }

  static Future<void> _checkAndProcessMonthlyRollover() async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);

    final prefs = await SharedPreferences.getInstance();
    final processedMonths =
        jsonDecode(
          prefs.getString(_processedMonthsKey) ?? '[]',
        ).map((e) => e.toString()).toSet();

    final transactions = await getTransactions();
    if (transactions.isEmpty) return;

    DateTime earliestDate = now;
    for (final t in transactions) {
      final d = DateTime.tryParse((t['date'] ?? '').toString());
      if (d != null && d.isBefore(earliestDate)) earliestDate = d;
    }

    DateTime monthIter = DateTime(earliestDate.year, earliestDate.month, 1);
    while (monthIter.isBefore(currentMonthStart)) {
      final key =
          '${monthIter.year}-${monthIter.month.toString().padLeft(2, '0')}';
      if (!processedMonths.contains(key)) {
        final balance = await calculateMonthEndBalance(
          monthIter.year,
          monthIter.month,
        );
        // Only carry forward if balance is positive. Negative becomes OWO.
        if (balance > 0) {
          await _addCarryForwardCredit(monthIter, balance);
        } else if (balance < 0) {
          await _addNegativeBalanceOwo(monthIter, balance.abs());
        }
        processedMonths.add(key);
      }
      monthIter = DateTime(monthIter.year, monthIter.month + 1, 1);
    }

    await prefs.setString(
      _processedMonthsKey,
      jsonEncode(processedMonths.toList()),
    );
    await prefs.setString(_lastMonthlyRolloverKey, now.toIso8601String());
  }

  // ------------------------------------------------------------
  // FIXED: guards against duplicate "Balance carried forward"
  // transactions. The local `_processedMonthsKey` flag above can be
  // lost relative to the cloud/transaction data (reinstall, simulator
  // fresh install, restoring an older backup, etc.), which previously
  // caused this method to insert a second carry-forward transaction
  // for a month that had already been rolled over. We now check the
  // actual transaction list — the real source of truth — before
  // inserting anything.
  // ------------------------------------------------------------
  static Future<void> _addCarryForwardCredit(
    DateTime month,
    double amount,
  ) async {
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final transactions = await getTransactions();

    final monthTag = '${month.year}_${month.month}';
    final alreadyExists = transactions.any((t) {
      final desc = (t['description'] ?? '').toString();
      final id = (t['transactionId'] ?? '').toString();
      return desc.contains(
            'Balance carried forward from ${_formatMonthName(month)}',
          ) ||
          id.startsWith('carry_$monthTag');
    });
    if (alreadyExists) return;

    final carryTxn = {
      'transactionId':
          'carry_${monthTag}_${DateTime.now().millisecondsSinceEpoch}',
      'description': 'Balance carried forward from ${_formatMonthName(month)}',
      'amount': amount,
      'type': 'Credit',
      'date': nextMonth.toIso8601String(),
      'category': '',
      'status': 'Completed',
      'isCarryForward': true,
    };

    transactions.add(carryTxn);
    await _saveToLocal(_transactionsKey, transactions);
    if (_isAuthenticated) {
      try {
        await SupabaseService.addTransaction(carryTxn);
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------
  // FIXED: same duplicate-insert guard as _addCarryForwardCredit,
  // applied to negative-balance OWO entries.
  // ------------------------------------------------------------
  static Future<void> _addNegativeBalanceOwo(
    DateTime month,
    double amount,
  ) async {
    final monthTag = '${month.year}_${month.month}';
    final entries = await getOwoEntries();
    final alreadyExists = entries.any((e) {
      final id = (e['id'] ?? '').toString();
      final note = (e['note'] ?? '').toString();
      return id.startsWith('neg_$monthTag') ||
          note.contains('Negative balance from ${_formatMonthName(month)}');
    });
    if (alreadyExists) return;

    final entry = {
      'id': 'neg_${monthTag}_${DateTime.now().millisecondsSinceEpoch}',
      'counterparty': '${_formatMonthName(month)} Balance',
      'direction': 'owe',
      'amount': amount,
      'note': 'Negative balance from ${_formatMonthName(month)}',
      'createdAt': DateTime(month.year, month.month + 1, 1).toIso8601String(),
      'settled': false,
      'isNegativeBalance': true,
    };
    await addOwoEntry(entry);
  }

  static String _formatMonthName(DateTime date) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[date.month - 1]} ${date.year}';
  }

  static Future<void> processMonthlyRollover() async =>
      await _checkAndProcessMonthlyRollover();

  static Future<void> syncOnLogin() async {
    if (!_isAuthenticated) return;
    try {
      // Local storage belongs to the previously active account. Never migrate
      // it automatically into a newly authenticated account.
      await clearLocalCache();
      await Future.wait([
        getCategories(),
        getTransactions(),
        getBudgets(),
        getOwoEntries(),
        getInitialBalance(),
      ]);
      await _checkAndProcessMonthlyRollover();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Removes all account-specific data cached on this device.
  /// Cloud records are intentionally left untouched.
  static Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_categoriesKey),
      prefs.remove(_transactionsKey),
      prefs.remove(_budgetsKey),
      prefs.remove(_owoKey),
      prefs.remove(_initialBalanceKey),
      prefs.remove(_lastSyncKey),
      prefs.remove(_lastMonthlyRolloverKey),
      prefs.remove(_processedMonthsKey),
      prefs.remove(_backupVersionKey),
      prefs.remove(_syncQueueKey),
      prefs.remove(_failedTransactionsKey),
    ]);
  }

  static Future<List<Map<String, dynamic>>> _getFromLocal(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.cast<Map<String, dynamic>>() : [];
  }

  static Future<void> _saveToLocal(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<bool> recoverFromCloud() async {
    if (!_isAuthenticated) return false;
    try {
      final cloudTransactions = await SupabaseService.getTransactions();
      final cloudCategories = await SupabaseService.getCategories();
      final cloudBudgets = await SupabaseService.getBudgets();
      final cloudOwoEntries = await SupabaseService.getOwoEntries();
      await _saveToLocal(_transactionsKey, cloudTransactions);
      await _saveToLocal(_categoriesKey, cloudCategories);
      await _saveToLocal(_budgetsKey, cloudBudgets);
      await _saveToLocal(_owoKey, cloudOwoEntries);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> createBackup({String? customName}) async {
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
    };
    await _saveBackupWithVersioning(backup);
    return backup;
  }

  static Future<void> _saveBackupWithVersioning(
    Map<String, dynamic> backup,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final versions = jsonDecode(prefs.getString(_backupVersionKey) ?? '[]');
    versions.add(backup);
    if (versions.length > _maxBackupVersions) versions.removeAt(0);
    await prefs.setString(_backupVersionKey, jsonEncode(versions));
  }

  static Future<List<Map<String, dynamic>>> getAllBackups() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString(_backupVersionKey) ?? '[]') as List)
        .cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>?> getLatestBackup() async {
    final b = await getAllBackups();
    return b.isNotEmpty ? b.last : null;
  }

  static Future<bool> restoreFromBackup([Map<String, dynamic>? backup]) async {
    try {
      final b = backup ?? await getLatestBackup();
      if (b == null) return false;
      await _saveToLocal(_transactionsKey, b['transactions'] ?? []);
      await _saveToLocal(_categoriesKey, b['categories'] ?? []);
      await _saveToLocal(_budgetsKey, b['budgets'] ?? {});
      await _saveToLocal(_owoKey, b['owoEntries'] ?? []);
      if (b['initialBalance'] != null)
        await setInitialBalance((b['initialBalance'] as num).toDouble());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteBackup(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final versions =
        (jsonDecode(prefs.getString(_backupVersionKey) ?? '[]') as List)
            .cast<Map<String, dynamic>>();
    versions.removeWhere((b) => b['timestamp'] == timestamp);
    await prefs.setString(_backupVersionKey, jsonEncode(versions));
    return true;
  }

  static Future<String> exportBackupToJson([
    Map<String, dynamic>? backup,
  ]) async {
    final b = backup ?? await getLatestBackup();
    return jsonEncode({'app': 'Vaultic', 'backup': b});
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? false;
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }

  static Future<void> checkAndPerformAutoBackup() async {
    if (!await isAutoBackupEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastAutoBackupKey);
    if (last == null ||
        DateTime.now().difference(DateTime.parse(last)).inDays >= 1) {
      await createBackup(customName: 'Auto Backup');
      await prefs.setString(
        _lastAutoBackupKey,
        DateTime.now().toIso8601String(),
      );
    }
  }

  static Future<void> _queueForSync(
    Map<String, dynamic> data,
    String op,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final q = jsonDecode(prefs.getString(_syncQueueKey) ?? '[]');
    q.add({
      'operation': op,
      'data': data,
      'nextRetry': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_syncQueueKey, jsonEncode(q));
  }

  static Future<Map<String, int>> processSyncQueue({bool force = false}) async {
    return {'success': 0, 'failed': 0};
  }

  static Future<Map<String, int>> syncNow() async {
    return {'success': 0, 'failed': 0};
  }
}

extension OwesOwnsStorage on HybridStorageService {
  static Future<List<Map<String, dynamic>>> getOwoEntries() =>
      HybridStorageService.getOwoEntries();
  static Future<void> saveOwoEntries(List<Map<String, dynamic>> list) =>
      HybridStorageService.saveOwoEntries(list);
  static Future<void> addOwoEntry(Map<String, dynamic> entry) =>
      HybridStorageService.addOwoEntry(entry);
  static Future<void> updateOwoEntry(Map<String, dynamic> entry) =>
      HybridStorageService.updateOwoEntry(entry);
  static Future<void> deleteOwoEntry(String id) =>
      HybridStorageService.deleteOwoEntry(id);
}
