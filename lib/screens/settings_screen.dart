import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/local_storage.dart';
import 'terms_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearLocalData(BuildContext context) async {
    // naive clear: overwrite with empty lists
    await LocalStorageService.saveCategories([]);
    await LocalStorageService.saveTransactions([]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local data cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
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
        ],
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


