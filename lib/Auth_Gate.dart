import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'SignUpPage.dart';
import 'HomePage.dart';
import 'OTPverification.dart';
import 'VaulticLogin.dart';
import 'services/hybrid_storage_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getHomeWidget(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('An error occurred')),
          );
        }

        return snapshot.data!;
      },
    );
  }
}
