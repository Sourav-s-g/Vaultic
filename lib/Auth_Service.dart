import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/hybrid_storage_service.dart';
import 'services/trip_storage_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );
    if (response.session != null) await _loadCurrentUserData();
    return response;
  }

  Future<AuthResponse> loginWithEmail(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await _loadCurrentUserData();
    return response;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.vaultic.app://reset-password',
    );
  }

  Future<void> updatePassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
    await _loadCurrentUserData();
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await HybridStorageService.clearLocalCache();
    await TripStorageService.clearLocalData();
  }

  Future<void> _loadCurrentUserData() async {
    await TripStorageService.clearLocalData();
    await HybridStorageService.syncOnLogin();
  }

  Future<bool> needsAppSetup() async {
    final categories = await HybridStorageService.getCategories();
    return categories.isEmpty;
  }

  static String messageForError(Object error) {
    if (error is AuthException) return error.message;
    return error.toString();
  }

  // Get currently signed-in user (returns user or null)
  User? getCurrentUser() {
    final session = _supabase.auth.currentSession;
    return session?.user;
  }
}
