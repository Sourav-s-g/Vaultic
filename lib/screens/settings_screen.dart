import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hybrid_storage_service.dart';
import 'terms_screen.dart';
import 'privacy_screen.dart';
import 'data_recovery_screen.dart';
import 'backup_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearLocalData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: const Text('Clear all local data?'),
        content: const Text('This will delete your categories, transactions, budgets and OWO entries from this device.'),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    // Backup current data for undo
    final categoriesBackup = await HybridStorageService.getCategories();
    final transactionsBackup = await HybridStorageService.getTransactions();
    final budgetsBackup = await HybridStorageService.getBudgets();
    final owoBackup = await OwesOwnsStorage.getOwoEntries();

    // Clear
    await HybridStorageService.saveCategories([]);
    await HybridStorageService.saveTransactions([]);
    await HybridStorageService.saveBudgets({});
    await OwesOwnsStorage.saveOwoEntries([]);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Local data cleared'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await HybridStorageService.saveCategories(categoriesBackup);
            await HybridStorageService.saveTransactions(transactionsBackup);
            await HybridStorageService.saveBudgets(budgetsBackup);
            await OwesOwnsStorage.saveOwoEntries(owoBackup);
          },
          textColor: Colors.yellow,
        ),
        duration: const Duration(seconds: 30),
      ),
    );
  }

  Future<void> _recoverFromCloud(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: const Text('Recover from Cloud?'),
        content: const Text('This will download all your data from the cloud and replace your local data.'),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Recover', style: TextStyle(color: Colors.green))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final success = await HybridStorageService.recoverFromCloud();
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Data recovered successfully!' : 'Recovery failed. Check your internet connection.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recovery failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: const Text('Restore from Backup?'),
        content: const Text('This will restore your data from the last backup. Current data will be replaced.'),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Restore', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final success = await HybridStorageService.restoreFromBackup();
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Data restored from backup!' : 'No backup found or restore failed.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncNow(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    );

    try {
      final results = await HybridStorageService.syncNow();
      if (!context.mounted) return;
      
      Navigator.pop(context); // Close loading dialog
      
      final successCount = results['success'] ?? 0;
      final failedCount = results['failed'] ?? 0;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount > 0
                ? 'Synced $successCount item(s)${failedCount > 0 ? '. $failedCount failed.' : ''}'
                : failedCount > 0
                    ? 'Sync failed for $failedCount item(s)'
                    : 'No items to sync',
          ),
          backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF032221), Colors.black],
            ),
          ),
          child: AppBar(
            title: Text('Settings', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Colors.black, Color(0xFF032221)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _tile(context, Icons.policy, 'Terms and Conditions', (){
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()));
            }),
            _tile(context, Icons.privacy_tip, 'Safety and Privacy Policy', (){
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
            }),
            const Divider(color: Colors.white24),
            _tile(context, Icons.delete_forever, 'Clear Local Data', (){ _clearLocalData(context); }),
            _tile(context, Icons.cloud_download, 'Recover from Cloud', (){ _recoverFromCloud(context); }),
            _tile(context, Icons.backup, 'Backup Management', (){ 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupManagementScreen()));
            }),
            _tile(context, Icons.cloud_sync, 'Sync Now', (){ _syncNow(context); }),
            _tile(context, Icons.restore, 'Restore from Backup', (){ _restoreFromBackup(context); }),
            _tile(context, Icons.emergency, 'Data Recovery Center', (){ 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DataRecoveryScreen()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: GoogleFonts.nunito(color: Colors.white, fontSize: 16)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }
}


