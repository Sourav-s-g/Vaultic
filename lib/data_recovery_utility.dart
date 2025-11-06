import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';
import 'services/hybrid_storage_service.dart';

class DataRecoveryUtility {
  /// Check all possible sources for transaction data
  static Future<Map<String, dynamic>> checkAllDataSources() async {
    final results = <String, dynamic>{};
    
    print('🔍 Checking all data sources...');
    
    // 1. Check local SharedPreferences
    results['local_data'] = await _checkLocalData();
    
    // 2. Check cloud data (if authenticated)
    results['cloud_data'] = await _checkCloudData();
    
    // 3. Check for backup data
    results['backup_data'] = await _checkBackupData();
    
    // 4. Check migration status
    results['migration_status'] = await _checkMigrationStatus();
    
    return results;
  }
  
  /// Check local SharedPreferences for any remaining data
  static Future<Map<String, dynamic>> _checkLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    final localData = <String, dynamic>{};
    
    // Check all Vaultic-related keys
    final vaulticKeys = keys.where((k) => k.startsWith('vaultic_')).toList();
    
    for (final key in vaulticKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          localData[key] = {
            'type': decoded.runtimeType.toString(),
            'size': value.length,
            'preview': _getPreview(decoded),
          };
        } catch (e) {
          localData[key] = {
            'type': 'String',
            'size': value.length,
            'preview': value.substring(0, value.length > 100 ? 100 : value.length),
          };
        }
      }
    }
    
    print('📱 Local data found: ${localData.length} keys');
    return localData;
  }
  
  /// Check cloud data from Supabase
  static Future<Map<String, dynamic>> _checkCloudData() async {
    if (SupabaseService.userId == null) {
      return {'status': 'not_authenticated'};
    }
    
    try {
      final transactions = await SupabaseService.getTransactions();
      final categories = await SupabaseService.getCategories();
      final budgets = await SupabaseService.getBudgets();
      final owoEntries = await SupabaseService.getOwoEntries();
      
      return {
        'status': 'authenticated',
        'transactions_count': transactions.length,
        'categories_count': categories.length,
        'budgets_count': budgets.length,
        'owo_entries_count': owoEntries.length,
        'transactions_preview': transactions.take(3).toList(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
  
  /// Check for backup data
  static Future<Map<String, dynamic>> _checkBackupData() async {
    final prefs = await SharedPreferences.getInstance();
    final backupJson = prefs.getString('vaultic_backup');
    
    if (backupJson == null) {
      return {'status': 'no_backup'};
    }
    
    try {
      final backup = jsonDecode(backupJson) as Map<String, dynamic>;
      return {
        'status': 'backup_found',
        'timestamp': backup['timestamp'],
        'transactions_count': (backup['transactions'] as List?)?.length ?? 0,
        'categories_count': (backup['categories'] as List?)?.length ?? 0,
        'budgets_count': (backup['budgets'] as Map?)?.length ?? 0,
        'owo_entries_count': (backup['owoEntries'] as List?)?.length ?? 0,
      };
    } catch (e) {
      return {
        'status': 'backup_corrupted',
        'error': e.toString(),
      };
    }
  }
  
  /// Check migration status
  static Future<Map<String, dynamic>> _checkMigrationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final migrationCompleted = prefs.getBool('vaultic_migration_completed_v1') ?? false;
    final lastSync = prefs.getString('vaultic_last_sync_v1');
    
    return {
      'migration_completed': migrationCompleted,
      'last_sync': lastSync,
    };
  }
  
  /// Get a preview of data for display
  static String _getPreview(dynamic data) {
    if (data is List) {
      return 'List with ${data.length} items';
    } else if (data is Map) {
      return 'Map with ${data.length} keys';
    } else {
      return data.toString();
    }
  }
  
  /// Attempt to recover data from all available sources
  static Future<bool> attemptRecovery() async {
    print('🔄 Attempting data recovery...');
    
    // First, try to recover from cloud
    if (SupabaseService.userId != null) {
      try {
        final success = await HybridStorageService.recoverFromCloud();
        if (success) {
          print('✅ Successfully recovered from cloud!');
          return true;
        }
      } catch (e) {
        print('❌ Cloud recovery failed: $e');
      }
    }
    
    // Then try to recover from backup
    try {
      final success = await HybridStorageService.restoreFromBackup();
      if (success) {
        print('✅ Successfully recovered from backup!');
        return true;
      }
    } catch (e) {
      print('❌ Backup recovery failed: $e');
    }
    
    print('❌ No recovery options available');
    return false;
  }
  
  /// Create a comprehensive backup of all current data
  static Future<Map<String, dynamic>> createEmergencyBackup() async {
    print('💾 Creating emergency backup...');
    final backup = await HybridStorageService.createBackup(customName: 'Emergency Backup');
    print('✅ Emergency backup created!');
    return backup;
  }
}
