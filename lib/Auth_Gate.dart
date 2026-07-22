import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'SignUpPage.dart';
import 'HomePage.dart';
import 'OTPverification.dart';
import 'VaulticLogin.dart';
import 'services/hybrid_storage_service.dart';
import '../screens/branded_background.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getHomeWidget() async {
    // Prefer cached OTP verification window to skip login entirely for 5 days
    final last = await HybridStorageService.getLastOtpVerification();
    final withinWindow = last != null && DateTime.now().difference(last).inDays < 5;
    if (withinWindow) {
      return const Homepage();
    }

    // Otherwise fall back to Supabase session state
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    if (user == null) {
      return const SignUpPage();
    }

    // Logged in but OTP window expired -> prompt verification
    final email = user.email ?? '';
    if (email.isNotEmpty) {
      return Vaulticlogin();
    }
    return const SignUpPage();
  }

  Widget _brandedLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF032221),
              Color(0xFF0D635F),
              Color(0xFF032221),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Vaultic',
                style: GoogleFonts.montserrat(
                  letterSpacing: 4,
                  color: Colors.white,
                  fontSize: 70,
                ),
              ),
              Text(
                'Your Smart Vault',
                style: GoogleFonts.openSans(
                  color: Colors.white,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getHomeWidget(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BrandedBackground();
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF032221),
            body: const Center(
              child: Text(
                'An error occurred',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return snapshot.data!;
      },
    );
  }
}