import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'SignUpPage.dart';
import 'HomePage.dart';
import 'Auth_Service.dart';
import 'screens/app_setup_screen.dart';
import '../screens/branded_background.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getHomeWidget() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    if (user == null) return const SignUpPage();
    final needsSetup = await AuthService().needsAppSetup();
    return needsSetup
        ? AppSetupScreen(userEmail: user.email ?? '')
        : const Homepage();
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
