import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/sms_service.dart';

/// Provider for SMS log/history, persisted locally via shared_preferences.
final smsLogProvider =
    StateNotifierProvider<SmsLogNotifier, AsyncValue<List<SmsLogEntry>>>(
      (ref) => SmsLogNotifier(),
    );

class SmsLogNotifier extends StateNotifier<AsyncValue<List<SmsLogEntry>>> {
  static const String _prefKey = 'sms_logs';
  static const int _maxEntries = 300;
  static int _idCounter = 0;

  SmsLogNotifier() : super(const AsyncValue.loading()) {
    loadLogs();
  }

  String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  Future<void> loadLogs() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefKey) ?? const [];
      final logs = raw
          .map((e) {
            try {
              return SmsLogEntry.fromJson(jsonDecode(e) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<SmsLogEntry>()
          .toList();
      state = AsyncValue.data(logs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Records a sent SMS in the history.
  Future<void> addLog(SmsLogEntry entry) async {
    final currentLogs = state.value ?? [];
    final updated = [entry, ...currentLogs];
    state = AsyncValue.data(updated);
    await _persist(updated);
  }

  /// Convenience helper: create + store a log entry in one call.
  Future<void> logSms({
    required String phone,
    required String studentName,
    required String message,
    required SmsType type,
    required bool success,
  }) {
    return addLog(
      SmsLogEntry(
        id: _nextId(),
        phone: phone,
        studentName: studentName,
        message: message,
        type: type,
        status: success ? SmsStatus.sent : SmsStatus.failed,
        sentAt: DateTime.now(),
      ),
    );
  }

  Future<void> clearLogs() async {
    state = const AsyncValue.data([]);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {
      // Ignore persistence errors; in-memory state is already cleared.
    }
  }

  Future<void> _persist(List<SmsLogEntry> logs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = logs.take(_maxEntries).toList();
      await prefs.setStringList(
        _prefKey,
        capped.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (_) {
      // Ignore persistence errors; in-memory state is still updated.
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Provider for SMS filter
// ─────────────────────────────────────────────────────────────
final smsFilterTypeProvider = StateProvider<SmsType?>((ref) => null);
