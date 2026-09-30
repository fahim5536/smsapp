import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/services/supabase_service.dart';
import '../models/fee_record_model.dart';
import '../models/student_model.dart';

/// Handles fee transactions and due tracking in Supabase
class FeeRepository {
  final SupabaseClient _db = SupabaseService.client;

  String _formatMonthKey(int month, int year) =>
      '$year-${month.toString().padLeft(2, '0')}';

  /// Fetches all fee records for a specific month and year
  Future<List<FeeRecordModel>> fetchFeesForMonth({
    required int month,
    required int year,
  }) async {
    final monthKey = _formatMonthKey(month, year);
    final data = await _db
        .from(SupabaseConfig.feesTable)
        .select()
        .eq('month', monthKey)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data)
        .map(FeeRecordModel.fromJson)
        .toList();
  }

  /// Upserts or updates a student's fee payment for a given month/year
  Future<FeeRecordModel> recordPayment({
    required String studentId,
    required int month,
    required int year,
    required double totalAmount,
    required double paidAmount,
    String? note,
  }) async {
    FeeStatus status;
    if (paidAmount >= totalAmount) {
      status = FeeStatus.paid;
    } else if (paidAmount > 0) {
      status = FeeStatus.partial;
    } else {
      status = FeeStatus.unpaid;
    }

    final monthKey = _formatMonthKey(month, year);
    final payload = {
      'student_id': studentId,
      'month': monthKey,
      'amount': totalAmount,
      'paid_amount': paidAmount,
      'status': status.value,
      'paid_date': paidAmount > 0 ? DateTime.now().toIso8601String() : null,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final data = await _db
        .from(SupabaseConfig.feesTable)
        .upsert(payload, onConflict: 'student_id,month')
        .select()
        .single();

    return FeeRecordModel.fromJson(data);
  }

  /// Automatically generates fee dues for all active students for a given month
  Future<void> initializeMonthFees({
    required List<StudentModel> students,
    required int month,
    required int year,
  }) async {
    final existingFees = await fetchFeesForMonth(month: month, year: year);
    final existingStudentIds = existingFees.map((f) => f.studentId).toSet();

    final missingStudents = students.where(
      (s) => s.isActive && !existingStudentIds.contains(s.id),
    );

    if (missingStudents.isEmpty) return;

    final monthKey = _formatMonthKey(month, year);
    final rows = missingStudents.map((s) => {
          'student_id': s.id,
          'month': monthKey,
          'amount': s.monthlyFee,
          'status': FeeStatus.unpaid.value,
        }).toList();

    await _db
        .from(SupabaseConfig.feesTable)
        .upsert(rows, onConflict: 'student_id,month');
  }
}
