import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/services/supabase_service.dart';
import '../models/attendance_model.dart';

/// Handles attendance persistence and queries against Supabase
class AttendanceRepository {
  final SupabaseClient _db = SupabaseService.client;

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Fetches all attendance records for a specific date
  Future<List<AttendanceModel>> fetchAttendanceForDate(DateTime date) async {
    final dateStr = _formatDate(date);
    final data = await _db
        .from(SupabaseConfig.attendanceTable)
        .select()
        .eq('date', dateStr);

    return List<Map<String, dynamic>>.from(data)
        .map(AttendanceModel.fromJson)
        .toList();
  }

  /// Upserts an attendance entry for a student on a given date.
  /// (Leverages the `uq_attendance_student_date` unique constraint)
  Future<AttendanceModel> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
    required DateTime date,
    String? note,
  }) async {
    final payload = {
      'student_id': studentId,
      'date': _formatDate(date),
      'status': status.value,
    };

    final data = await _db
        .from(SupabaseConfig.attendanceTable)
        .upsert(payload, onConflict: 'student_id,date')
        .select()
        .single();

    return AttendanceModel.fromJson(data);
  }

  /// Batch marks attendance (e.g. "Mark All Present")
  Future<void> batchRecordAttendance({
    required List<String> studentIds,
    required AttendanceStatus status,
    required DateTime date,
  }) async {
    if (studentIds.isEmpty) return;

    final dateStr = _formatDate(date);
    final rows = studentIds.map((id) => {
          'student_id': id,
          'date': dateStr,
          'status': status.value,
        }).toList();

    await _db
        .from(SupabaseConfig.attendanceTable)
        .upsert(rows, onConflict: 'student_id,date');
  }

  /// Removes an attendance record for a student on a specific date
  Future<void> removeAttendance({
    required String studentId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    await _db
        .from(SupabaseConfig.attendanceTable)
        .delete()
        .eq('student_id', studentId)
        .eq('date', dateStr);
  }
}
