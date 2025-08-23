import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Passwordless Sign Up with Email
  Future<void> signUpWithEmail(String email) async {
    await _supabase.auth.signInWithOtp(email: email);
  }

  // Passwordless Login with Email
  Future<void> loginWithEmail(String email) async {
    await _supabase.auth.signInWithOtp(email: email);
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get currently signed-in user (returns user or null)
  User? getCurrentUser() {
    final session = _supabase.auth.currentSession;
    return session?.user;
  }
}
