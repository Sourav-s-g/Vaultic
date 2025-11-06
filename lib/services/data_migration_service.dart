import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class DataMigrationService {
  static const String _migrationKey = 'vaultic_migration_completed_v1';
  
  /// Migrate existing local data to Supabase for authenticated users
  static Future<void> migrateLocalDataToCloud() async {
    if (SupabaseService.userId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final migrationCompleted = prefs.getBool(_migrationKey) ?? false;
    
    if (migrationCompleted) return;
    
    try {
      print('Starting data migration...');
      
      // Migrate categories
      try {
        final categoriesRaw = prefs.getString('vaultic_categories_v1');
        if (categoriesRaw != null && categoriesRaw.isNotEmpty) {
          final categories = jsonDecode(categoriesRaw) as List;
          if (categories.isNotEmpty) {
            await SupabaseService.saveCategories(categories.cast<Map<String, dynamic>>());
            print('Categories migrated: ${categories.length}');
          }
        }
      } catch (e) {
        print('Error migrating categories: $e');
      }
      
      // Migrate transactions
      try {
        final transactionsRaw = prefs.getString('vaultic_transactions_v1');
        if (transactionsRaw != null && transactionsRaw.isNotEmpty) {
          final transactions = jsonDecode(transactionsRaw) as List;
          if (transactions.isNotEmpty) {
            await SupabaseService.saveTransactions(transactions.cast<Map<String, dynamic>>());
            print('Transactions migrated: ${transactions.length}');
          }
        }
      } catch (e) {
        print('Error migrating transactions: $e');
      }
      
      // Migrate budgets
      try {
        final budgetsRaw = prefs.getString('vaultic_budgets_v1');
        if (budgetsRaw != null && budgetsRaw.isNotEmpty) {
          final budgetsList = jsonDecode(budgetsRaw) as List;
          if (budgetsList.isNotEmpty) {
            final budgets = budgetsList.first as Map<String, dynamic>;
            if (budgets.isNotEmpty) {
              final budgetsMap = budgets.map((k, v) => MapEntry(k, (v as num).toDouble()));
              await SupabaseService.saveBudgets(budgetsMap);
              print('Budgets migrated: ${budgets.length}');
            }
          }
        }
      } catch (e) {
        print('Error migrating budgets: $e');
      }
      
      // Migrate OWO entries
      try {
        final owoRaw = prefs.getString('vaultic_owo_v1');
        if (owoRaw != null && owoRaw.isNotEmpty) {
          final owoEntries = jsonDecode(owoRaw) as List;
          if (owoEntries.isNotEmpty) {
            await SupabaseService.saveOwoEntries(owoEntries.cast<Map<String, dynamic>>());
            print('OWO entries migrated: ${owoEntries.length}');
          }
        }
      } catch (e) {
        print('Error migrating OWO entries: $e');
      }
      
      // Mark migration as completed
      await prefs.setBool(_migrationKey, true);
      print('Data migration completed successfully');
      
    } catch (e) {
      print('Migration failed: $e');
      // Don't mark as completed if it failed
    }
  }
  
  /// Clear migration flag (for testing)
  static Future<void> resetMigrationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationKey);
  }
}
