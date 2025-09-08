import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      appBar: AppBar(
        title: Text('Safety and Privacy Policy', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          'This is a placeholder privacy policy for Vaultic. Replace with your actual privacy and safety details.\n\n- Data storage: local only.\n- Permissions: ...',
          style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
      ),
    );
  }
}


