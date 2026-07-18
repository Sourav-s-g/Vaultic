import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hybrid_storage_service.dart';
import 'backup_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _profileExpanded = false;

  static const String _privacyPolicyUrl = 'https://sourav-s-g.github.io/Vaultic/';

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(_privacyPolicyUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the privacy policy link.')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        backgroundColor: const Color(0xFF0E1F1F),
        title: Text('Log out?', style: GoogleFonts.nunito(color: Colors.white)),
        content: Text('You will need to sign in again with an OTP to continue using Vaultic.', style: GoogleFonts.nunito(color: Colors.white70)),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Log Out', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (!context.mounted) return;
      // TODO: Replace '/login' with your actual login/entry route name.
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _clearLocalData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        backgroundColor: const Color(0xFF0E1F1F),
        title: Text('Clear all local data?', style: GoogleFonts.nunito(color: Colors.white)),
        content: Text('This will delete your categories, transactions, budgets and OWO entries from this device.', style: GoogleFonts.nunito(color: Colors.white70)),
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
        backgroundColor: const Color(0xFF0E1F1F),
        title: Text('Recover from Cloud?', style: GoogleFonts.nunito(color: Colors.white)),
        content: Text('This will download all your data from the cloud and replace your local data.', style: GoogleFonts.nunito(color: Colors.white70)),
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
        backgroundColor: const Color(0xFF0E1F1F),
        title: Text('Restore from Backup?', style: GoogleFonts.nunito(color: Colors.white)),
        content: Text('This will restore your data from the last backup. Current data will be replaced.', style: GoogleFonts.nunito(color: Colors.white70)),
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

      Navigator.pop(context);

      final successCount = results['success'] ?? 0;
      final failedCount = results['failed'] ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount > 0
                ? 'Synced $successCount item(s)${failedCount > 0 ? ". $failedCount failed." : ""}'
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
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
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
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Color(0xFF0C4340), Color(0xFF032221)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _profileTile(context),
              _tile(context, Icons.backup, 'Backup Management', (){
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupManagementScreen()));
              }),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _gridTile(context, Icons.delete_forever, 'Clear Local Data', (){ _clearLocalData(context); }),
                  _gridTile(context, Icons.cloud_download, 'Recover from Cloud', (){ _recoverFromCloud(context); }),
                  _gridTile(context, Icons.cloud_sync, 'Sync Now', (){ _syncNow(context); }),
                  _gridTile(context, Icons.restore, 'Restore from Backup', (){ _restoreFromBackup(context); }),
                ],
              ),
              const Divider(color: Colors.white24, height: 32),
              _tile(context, Icons.privacy_tip, 'Privacy Policy', (){ _openPrivacyPolicy(context); }),
              _tile(context, Icons.logout, 'Log Out', (){ _logout(context); }, iconColor: Colors.red, titleColor: Colors.red),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileTile(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'Not signed in';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person, color: Colors.green),
            title: Text('Profile', style: GoogleFonts.nunito(color: Colors.white, fontSize: 16)),
            trailing: AnimatedRotation(
              turns: _profileExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more, color: Colors.white70),
            ),
            onTap: () {
              setState(() { _profileExpanded = !_profileExpanded; });
            },
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _profileExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext context,
      IconData icon,
      String title,
      VoidCallback onTap, {
        Color iconColor = Colors.green,
        Color titleColor = Colors.white,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: GoogleFonts.nunito(color: titleColor, fontSize: 16)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }

  Widget _gridTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.green, size: 26),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}