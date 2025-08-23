import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'SignUpPage.dart'; // Replace with your actual page
import 'HomePage.dart';   // Replace with your actual page

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getHomeWidget() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;

    // If not logged in, show signup/login
    if (user == null) {
      return const SignUpPage(); // Replace with your signup page widget
    }
    // If logged in, go to home page
    return const Homepage(); // Replace with your main/home page widget
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
