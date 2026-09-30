import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/sms_service.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../repositories/attendance_repository.dart';
import 'sms_provider.dart';

// ── Repository Provider ─────────────────────────────────────────
final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (_) => AttendanceRepository(),
);

// ── Coaching Name Provider ──────────────────────────────────────
class CoachingNameNotifier extends Notifier<String> {
  @override
  String build() => SmsService.coachingName;

  void updateName(String newName) {
    if (newName.trim().isNotEmpty) {
      state = newName.trim();
      SmsService.coachingName = state;
    }
  }
}

final coachingNameProvider =
    NotifierProvider<CoachingNameNotifier, String>(CoachingNameNotifier.new);

// ── Selected Date Notifier ──────────────────────────────────────
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void nextDay() {
    state = state.add(const Duration(days: 1));
  }

  void previousDay() {
    state = state.subtract(const Duration(days: 1));
  }

  void setToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final selectedAttendanceDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

// ── Attendance Map for Selected Date ───────────────────────────
/// Map of [studentId -> AttendanceModel] for the selected date
class AttendanceMapNotifier
    extends AsyncNotifier<Map<String, AttendanceModel>> {
  @override
  Future<Map<String, AttendanceModel>> build() async {
    final date = ref.watch(selectedAttendanceDateProvider);
    final repo = ref.watch(attendanceRepositoryProvider);
    final records = await repo.fetchAttendanceForDate(date);
    return {for (var r in records) r.studentId: r};
  }

  /// Marks a single student as present or absent, saves to Supabase,
  /// and triggers SMS if absent.
  Future<bool> markStudent({
    required StudentModel student,
    required AttendanceStatus status,
    bool autoSendSms = true,
  }) async {
    final date = ref.read(selectedAttendanceDateProvider);
    final repo = ref.read(attendanceRepositoryProvider);

    // Optimistically update local map
    final previousState = state.value ?? {};
    final tempRecord = AttendanceModel(
      id: previousState[student.id]?.id ?? '',
      teacherId: student.teacherId,
      studentId: student.id,
      date: date,
      status: status,
      createdAt: DateTime.now(),
    );

    state = AsyncData({...previousState, student.id: tempRecord});

    try {
      final saved = await repo.recordAttendance(
        studentId: student.id,
        status: status,
        date: date,
      );

      // Update with server returned record
      state = AsyncData({...state.value ?? {}, student.id: saved});
    } catch (e) {
      // Save failed — revert the optimistic update. Attendance is not
      // rolled back by an SMS failure; that is handled separately below.
      state = AsyncData(previousState);
      return false;
    }

    // If absent and autoSendSms is true, trigger the SMS app.
    // A launch failure must not undo the saved attendance.
    if (status == AttendanceStatus.absent && autoSendSms) {
      final coaching = ref.read(coachingNameProvider);
      final message = SmsService.generateAbsentMessage(
        studentName: student.fullName,
        customCoachingName: coaching,
        date: date,
      );
      final sent = await SmsService.sendCustomSms(
        phone: student.parentPhone,
        message: message,
      );
      await ref.read(smsLogProvider.notifier).logSms(
            phone: student.parentPhone,
            studentName: student.fullName,
            message: message,
            type: SmsType.absent,
            success: sent,
          );
    }
    return true;
  }

  /// Marks all specified students as Present in one batch operation
  Future<bool> markAllPresent(List<StudentModel> students) async {
    if (students.isEmpty) return true;

    final date = ref.read(selectedAttendanceDateProvider);
    final repo = ref.read(attendanceRepositoryProvider);

    final previousMap = Map<String, AttendanceModel>.from(state.value ?? {});
    final currentMap = Map<String, AttendanceModel>.from(previousMap);

    for (final s in students) {
      currentMap[s.id] = AttendanceModel(
        id: currentMap[s.id]?.id ?? '',
        teacherId: s.teacherId,
        studentId: s.id,
        date: date,
        status: AttendanceStatus.present,
        createdAt: DateTime.now(),
      );
    }
    state = AsyncData(currentMap);

    try {
      await repo.batchRecordAttendance(
        studentIds: students.map((s) => s.id).toList(),
        status: AttendanceStatus.present,
        date: date,
      );
      // Reload fresh records
      ref.invalidateSelf();
      return true;
    } catch (e) {
      state = AsyncData(previousMap);
      return false;
    }
  }

  /// Removes attendance record (resets to unrecorded)
  Future<bool> unmarkStudent(String studentId) async {
    final date = ref.read(selectedAttendanceDateProvider);
    final repo = ref.read(attendanceRepositoryProvider);

    final previousMap = Map<String, AttendanceModel>.from(state.value ?? {});
    final currentMap = Map<String, AttendanceModel>.from(previousMap)
      ..remove(studentId);
    state = AsyncData(currentMap);

    try {
      await repo.removeAttendance(studentId: studentId, date: date);
      return true;
    } catch (e) {
      state = AsyncData(previousMap);
      return false;
    }
  }
}

final attendanceMapProvider =
    AsyncNotifierProvider<AttendanceMapNotifier, Map<String, AttendanceModel>>(
  AttendanceMapNotifier.new,
);
