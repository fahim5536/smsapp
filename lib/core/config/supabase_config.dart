/// Supabase project credentials.
///
/// Pass at build time via --dart-define so secrets never appear in source:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // ── Table names ────────────────────────────────────────────
  static const String teachersTable   = 'teachers';
  static const String studentsTable   = 'students';
  static const String attendanceTable = 'attendance';
  static const String feesTable       = 'fees';
  static const String routinesTable   = 'routines';
}
