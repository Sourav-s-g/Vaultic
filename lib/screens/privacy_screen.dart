import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
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
            title: Text('Safety and Privacy Policy', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Vaultic Safety and Privacy Policy\n1. Data Security\nVaultic uses advanced encryption to store and transmit your financial data. User authentication includes options such as biometric security (Face ID, fingerprint) and multi-factor authentication.\n2. Data Collection\nWe collect only necessary data related to your linked bank transactions to provide our services. We do not sell or share your personal data with unauthorized third parties.\n3. User Consent\nBy connecting your bank accounts, you consent to the retrieval and processing of transaction data.\n4. Data Storage\nYour data is securely stored in cloud databases with strict access controls. We retain data only as long as necessary for service provision.\n5. User Controls\nUsers can delete their account at any time, which will remove their data from our systems, subject to legal retention requirements.\n6. Compliance\nVaultic complies with relevant data protection regulations including GDPR and local financial data privacy laws.\n7. Contact\nFor any privacy concerns, users can contact our support at support@vaultic.app.\nIf you want, this can be further customized or expanded with more specific legal language or app features. Would you like a more detailed or legally vetted version?',
            style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ),
      ),
    );
  }
}


