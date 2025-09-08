import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _categoriesKey = 'vaultic_categories_v1';
  static const String _transactionsKey = 'vaultic_transactions_v1';

  // Categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoriesKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesKey, jsonEncode(categories));
  }

  static Future<void> addCategory(Map<String, dynamic> category) async {
    final categories = await getCategories();
    // Avoid duplicates by name
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
  }

  // Transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_transactionsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<void> saveTransactions(List<Map<String, dynamic>> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_transactionsKey, jsonEncode(transactions));
  }

  static Future<void> addTransaction(Map<String, dynamic> txn) async {
    final txns = await getTransactions();
    txns.add(txn);
    await saveTransactions(txns);
  }
}


