import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'providers/teacher_provider.dart';
import 'screens/auth/phone_auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bengali digits/month names for DateFormat(..., 'bn') used across the app.
  await initializeDateFormatting('bn');

  // ── Initialize Supabase ──────────────────────────────────
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
    debug: kDebugMode,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  runApp(
    // ProviderScope is required for Riverpod
    const ProviderScope(child: TuitionApp()),
  );
}

class TuitionApp extends StatelessWidget {
  const TuitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuition Manager',
      debugShowCheckedModeBanner: false,
      darkTheme: AppTheme.dark,
      // The whole UI is designed dark-first; always use the dark theme.
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

/// AuthGate is the ONLY place that swaps between PhoneAuthScreen and
/// HomeScreen. Screens must never navigate away from it, otherwise this
/// state (and its auth listener) is destroyed and logout stops working.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _isLoading = true;
  bool _hasValidSession = false;
  int _checkSeq = 0;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _authSub = SupabaseService.authStateChanges.listen((state) {
      final event = state.event;
      final isSignOut = event == AuthChangeEvent.signedOut;
      final hasUser = state.session?.user != null;
      if (isSignOut || hasUser) {
        _checkSession();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    // Sign-in fires an auth event *before* the teachers row is linked, so a
    // second check starts right after. Ignore whichever result comes back
    // from an older check, otherwise the stale one can win and leave the
    // user on the login screen.
    final seq = ++_checkSeq;

    try {
      final user = SupabaseService.currentUser;

      if (user == null) {
        if (!mounted || seq != _checkSeq) return;
        setState(() {
          _hasValidSession = false;
          _isLoading = false;
        });
        return;
      }

      // Check if user has a teacher profile
      final teachers = await SupabaseService.client
          .from('teachers')
          .select('id')
          .eq('auth_user_id', user.id)
          .limit(1);

      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _hasValidSession = teachers.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _hasValidSession = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sign-in finishes linking the teachers row after the auth event,
    // so re-check when the login screen signals completion.
    ref.listen(authRefreshProvider, (_, _) => _checkSession());

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _hasValidSession ? const HomeScreen() : const PhoneAuthScreen();
  }
}
