/// Supabase project credentials.
///
/// Pass at build time via --dart-define so secrets never appear in source:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fhuxnoksaptskootgorz.supabase.co', // replace for dev
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZodXhub2tzYXB0c2tvb3Rnb3J6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMzkyODUsImV4cCI6MjEwNTkxNTI4NX0.J_ne0_zim4ZaZ1Ju9LBQupamEvq45vNbJjOwA7LQ23g', // replace for dev
  );

  // ── Table names ────────────────────────────────────────────
  static const String teachersTable   = 'teachers';
  static const String studentsTable   = 'students';
  static const String attendanceTable = 'attendance';
  static const String feesTable       = 'fees';
  static const String routinesTable   = 'routines';
}
