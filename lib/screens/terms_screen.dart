import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terms and Conditions', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Colors.black, Color(0xFF032221)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Vaultic Terms and Conditions\n1. Introduction\nVaultic is an expense tracking app that aggregates and syncs your bank transaction data to provide insights into your monthly spending and savings. By using Vaultic, you agree to these Terms and Conditions.\n2. User Account and Security\nUsers must provide accurate account information and maintain the confidentiality of their login credentials. Vaultic is not responsible for unauthorized access due to user negligence.\n3. Data Use and Privacy\nVaultic collects financial transaction data from linked bank accounts solely to provide expense tracking services. This data is handled according to our Privacy Policy.\n4. Service Availability\nWhile Vaultic strives for continuous service, we do not guarantee uninterrupted access and are not liable for any downtime or data loss.\n5. User Responsibilities\nUsers agree to use Vaultic lawfully and not for fraudulent activities. Misuse may lead to suspension or termination of accounts.\n6. Limitation of Liability\nVaultic is not liable for financial decisions based on app data or any third-party service interruptions affecting transaction syncing.\n7. Changes to Terms\nWe reserve the right to update these Terms at any time. Users will be notified of major changes.',
            style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ),
      ),
    );
  }
}


