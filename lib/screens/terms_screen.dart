import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      appBar: AppBar(
        title: Text('Terms and Conditions', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          'These are placeholder terms and conditions for Vaultic. Replace with your actual policies.\n\n1. Use of the app...\n2. Data handling...\n3. Liability...',
          style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
      ),
    );
  }
}


