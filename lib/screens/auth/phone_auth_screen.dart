import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/supabase_service.dart';
import '../../providers/teacher_provider.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    final value = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('+')) {
      return value;
    }
    if (value.startsWith('0')) {
      return '+88$value';
    }
    return '+$value';
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _createTeacherAccount() async {
    final rawPhone = _phoneController.text.trim();
    final phone = _normalizePhone(rawPhone);
    final name = _nameController.text.trim();

    if (phone.isEmpty || phone.length < 10) {
      _showSnackBar('সঠিক মোবাইল নম্বর দিন');
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Check if teacher already exists with this phone
      final existingTeachers = await SupabaseService.client
          .from('teachers')
          .select('id')
          .eq('phone', phone);

      if (existingTeachers.isNotEmpty) {
        // ── Re-login flow ──────────────────────────────────
        // Anonymous sign-in always creates a NEW auth user id, so we
        // re-link teachers.auth_user_id to this fresh session via the
        // login_teacher() RPC (security definer, bypasses RLS).
        final authResponse = await SupabaseService.signInAnonymously();
        final user = authResponse.user;

        if (user == null) {
          throw Exception('Auth user creation failed');
        }

        await SupabaseService.client.rpc(
          'login_teacher',
          params: {'p_phone': phone},
        );

        // AuthGate owns the Home/Login switch. Navigating from here would
        // destroy AuthGate (and its auth listener), breaking logout.
        if (!mounted) return;
        ref.read(authRefreshProvider.notifier).trigger();
        return;
      }

      if (name.isEmpty) {
        _showSnackBar('শিক্ষকের নাম দিন');
        return;
      }

      // ── New account creation ───────────────────────────
      // Sign in anonymously to get auth_user_id
      final authResponse = await SupabaseService.signInAnonymously();
      final user = authResponse.user;

      if (user == null) {
        throw Exception('Auth user creation failed');
      }

      // Create teacher record
      final row = {
        'auth_user_id': user.id,
        'full_name': name,
        'phone': phone,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await SupabaseService.client
          .from('teachers')
          .insert(row)
          .select();

      if (!mounted) return;
      ref.read(authRefreshProvider.notifier).trigger();
    } catch (e) {
      _showSnackBar('অ্যাকাউন্ট তৈরি করতে সমস্যা হয়েছে: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 52,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'শিক্ষক লগইন / একাউন্ট তৈরি',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'পুরনো নম্বর হলে শুধু মোবাইল নম্বর দিয়ে লগইন করুন। নতুন হলে নামসহ তথ্য দিন।',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'শিক্ষকের নাম',
                      hintText: 'শিক্ষকের সম্পূর্ণ নাম',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'মোবাইল নম্বর',
                      hintText: '017XXXXXXXX',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isCreating ? null : _createTeacherAccount,
                    child: _isCreating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('লগইন / একাউন্ট তৈরি করুন'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
