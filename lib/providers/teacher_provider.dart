import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';

/// Incremented after a sign-in/sign-up completes so AuthGate re-checks the
/// teachers row. Needed because the auth event fires *before* the row is
/// linked (login_teacher RPC / insert), so the auth listener alone would
/// still see "no teacher" and stay on the login screen.
class AuthRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state = state + 1;
}

final authRefreshProvider =
    NotifierProvider<AuthRefreshNotifier, int>(AuthRefreshNotifier.new);

/// Teacher profile of the currently signed-in auth user.
/// Null when the session has no linked teachers row.
final teacherProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) return null;

  final row = await SupabaseService.client
      .from('teachers')
      .select()
      .eq('auth_user_id', user.id)
      .maybeSingle();

  return row;
});
