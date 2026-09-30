import 'package:supabase_flutter/supabase_flutter.dart';

/// Global typed accessor for the Supabase client.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  /// Returns current user's UUID or a fallback ID when running without auth
  static String get currentUserId {
    final user = currentUser;
    return user?.id ?? 'anon_user';
  }

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<AuthResponse> signInAnonymously() async =>
      client.auth.signInAnonymously();
}
