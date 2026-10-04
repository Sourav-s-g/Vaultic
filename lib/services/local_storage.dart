import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/category_name.dart';

class HybridStorageService {
  static const String _categoriesKey = 'vaultic_categories_v1';
  static const String _transactionsKey = 'vaultic_transactions_v1';
  static const String _transactionsByMonthPrefix =
      'vaultic_txns_month_'; // + YYYY-MM
  static const String _txIdToMonthIndexKey =
      'vaultic_txn_index_v1'; // {id: 'YYYY-MM'}
  static const String _budgetsKey = 'vaultic_budgets_v1'; // {category: double}
  static const String _owoKey = 'vaultic_owo_v1';

  // Categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoriesKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      final categories =
          deduplicateCategories(decoded.cast<Map<String, dynamic>>());
      if (categories.length != decoded.length) {
        await prefs.setString(_categoriesKey, jsonEncode(categories));
      }
      return categories;
    }
    return [];
  }

  static Future<void> saveCategories(
    List<Map<String, dynamic>> categories,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _categoriesKey,
      jsonEncode(deduplicateCategories(categories)),
    );
  }

  static Future<void> addCategory(Map<String, dynamic> category) async {
    final categories = await getCategories();
    final name = (category['name'] ?? '').toString();
    if (name.trim().isNotEmpty &&
        !categoryNameExists(
          categories.map((c) => (c['name'] ?? '').toString()),
          name,
        )) {
      categories.add(category);
      await saveCategories(categories);
    }
  }

  static Future<void> removeCategoryByName(String name) async {
    final categories = await getCategories();
    final normalizedName = normalizeCategoryName(name);
    final storedNames = categories
        .map((c) => (c['name'] ?? '').toString())
        .where((stored) => normalizeCategoryName(stored) == normalizedName)
        .toList();
    final nameToRemove = storedNames.isEmpty ? name : storedNames.first;
    categories.removeWhere(
      (c) => (c['name'] ?? '').toString() == nameToRemove,
    );
    await saveCategories(categories);
    // Also remove budget for this category
    await removeBudget(nameToRemove);
    // Optionally, you might also want to remove transactions of this category.
  }

  // Transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyTransactionsIfNeeded(prefs);
    final keys =
        prefs
            .getKeys()
            .where((k) => k.startsWith(_transactionsByMonthPrefix))
            .toList();
    final result = <Map<String, dynamic>>[];
    for (final k in keys) {
      final raw = prefs.getString(k);
      if (raw == null || raw.isEmpty) continue;
      final decoded = jsonDecode(raw);
      if (decoded is List) result.addAll(decoded.cast<Map<String, dynamic>>());
    }
    return result;
  }

  static Future<void> saveTransactions(
    List<Map<String, dynamic>> transactions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final monthToList = <String, List<Map<String, dynamic>>>{};
    final idToMonth = <String, String>{};
    for (final t in transactions) {
      final dt =
          DateTime.tryParse((t['date'] ?? '').toString()) ?? DateTime.now();
      final month = _formatMonthKey(dt);
      final id = (t['transactionId'] ?? '').toString();
      monthToList.putIfAbsent(month, () => <Map<String, dynamic>>[]).add(t);
      if (id.isNotEmpty) idToMonth[id] = month;
    }
    // Clear old monthly buckets
    for (final k in prefs.getKeys().where(
      (k) => k.startsWith(_transactionsByMonthPrefix),
    )) {
      await prefs.remove(k);
    }
    // Write new
    for (final e in monthToList.entries) {
      await prefs.setString(_monthBucketKey(e.key), jsonEncode(e.value));
    }
    await prefs.setString(_txIdToMonthIndexKey, jsonEncode(idToMonth));
    await prefs.remove(_transactionsKey);
  }

  static Future<void> addTransaction(Map<String, dynamic> txn) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyTransactionsIfNeeded(prefs);
    final dt =
        DateTime.tryParse((txn['date'] ?? '').toString()) ?? DateTime.now();
    final month = _formatMonthKey(dt);
    final key = _monthBucketKey(month);
    final list = await _readBucket(prefs, key);
    list.add(txn);
    await prefs.setString(key, jsonEncode(list));
    final id = (txn['transactionId'] ?? '').toString();
    if (id.isNotEmpty) {
      final index = await _readIndex(prefs);
      index[id] = month;
      await _writeIndex(prefs, index);
    }
  }

  static Future<void> updateTransactionById(
    String transactionId,
    Map<String, dynamic> updatedFields,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyTransactionsIfNeeded(prefs);
    final index = await _readIndex(prefs);
    final currentMonth = index[transactionId];
    if (currentMonth == null) return;
    final currentKey = _monthBucketKey(currentMonth);
    var list = await _readBucket(prefs, currentKey);
    final idx = list.indexWhere(
      (t) => (t['transactionId'] ?? '').toString() == transactionId,
    );
    if (idx == -1) return;
    final original = Map<String, dynamic>.from(list[idx]);
    final merged = original..addAll(updatedFields);
    final newDt =
        DateTime.tryParse((merged['date'] ?? '').toString()) ?? DateTime.now();
    final newMonth = _formatMonthKey(newDt);
    if (newMonth != currentMonth) {
      list.removeAt(idx);
      await prefs.setString(currentKey, jsonEncode(list));
      final newKey = _monthBucketKey(newMonth);
      final newList = await _readBucket(prefs, newKey);
      newList.add(merged);
      await prefs.setString(newKey, jsonEncode(newList));
      index[transactionId] = newMonth;
      await _writeIndex(prefs, index);
    } else {
      list[idx] = merged;
      await prefs.setString(currentKey, jsonEncode(list));
    }
  }

  // Transaction helpers
  static Future<void> deleteTransactionById(String transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyTransactionsIfNeeded(prefs);
    final index = await _readIndex(prefs);
    final month = index[transactionId];
    if (month == null) return;
    final key = _monthBucketKey(month);
    final list = await _readBucket(prefs, key);
    list.removeWhere(
      (t) => (t['transactionId'] ?? '').toString() == transactionId,
    );
    await prefs.setString(key, jsonEncode(list));
    index.remove(transactionId);
    await _writeIndex(prefs, index);
  }

  // Budgets per category
  static Future<Map<String, double>> getBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_budgetsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded.map(
        (k, v) => MapEntry(
          k,
          (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0,
        ),
      );
    }
    return {};
  }

  static Future<void> saveBudgets(Map<String, double> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_budgetsKey, jsonEncode(budgets));
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

  // --------- Internal helpers for month-bucketed transactions ---------
  static String _formatMonthKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  static String _monthBucketKey(String monthKey) =>
      '${_transactionsByMonthPrefix}$monthKey';

  static Future<List<Map<String, dynamic>>> _readBucket(
    SharedPreferences prefs,
    String key,
  ) async {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    return <Map<String, dynamic>>[];
  }

  static Future<Map<String, String>> _readIndex(SharedPreferences prefs) async {
    final raw = prefs.getString(_txIdToMonthIndexKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    }
    return <String, String>{};
  }

  static Future<void> _writeIndex(
    SharedPreferences prefs,
    Map<String, String> index,
  ) async {
    await prefs.setString(_txIdToMonthIndexKey, jsonEncode(index));
  }

  static Future<void> _migrateLegacyTransactionsIfNeeded(
    SharedPreferences prefs,
  ) async {
    // If legacy blob exists and no monthly buckets yet, migrate
    final legacy = prefs.getString(_transactionsKey);
    final hasBuckets = prefs.getKeys().any(
      (k) => k.startsWith(_transactionsByMonthPrefix),
    );
    if (legacy == null || legacy.isEmpty || hasBuckets) return;
    final decoded = jsonDecode(legacy);
    if (decoded is! List) return;
    final list = decoded.cast<Map<String, dynamic>>();
    await saveTransactions(list);
  }
}

// Owes & Owns storage helpers
extension OwesOwnsStorage on HybridStorageService {
  static Future<List<Map<String, dynamic>>> getOwoEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(HybridStorageService._owoKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    return [];
  }

  static Future<void> saveOwoEntries(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(HybridStorageService._owoKey, jsonEncode(list));
  }

  static Future<void> addOwoEntry(Map<String, dynamic> entry) async {
    final list = await getOwoEntries();
    list.add(entry);
    await saveOwoEntries(list);
  }

  static Future<void> updateOwoEntry(Map<String, dynamic> entry) async {
    final list = await getOwoEntries();
    final id = (entry['id'] ?? '').toString();
    final idx = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (idx != -1) {
      list[idx] = entry;
      await saveOwoEntries(list);
    }
  }

  static Future<void> deleteOwoEntry(String id) async {
    final list = await getOwoEntries();
    list.removeWhere((e) => (e['id'] ?? '').toString() == id);
    await saveOwoEntries(list);
  }
}
