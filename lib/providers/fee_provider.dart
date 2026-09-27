import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/sms_service.dart';
import '../models/fee_record_model.dart';
import '../models/student_model.dart';
import '../repositories/fee_repository.dart';
import 'attendance_provider.dart';
import 'student_provider.dart';

final feeRepositoryProvider = Provider<FeeRepository>((_) => FeeRepository());

// ── Selected Month / Year Notifier ──────────────────────────────
class MonthYearState {
  final int month;
  final int year;
  const MonthYearState({required this.month, required this.year});

  String get displayBn => '${FeeRecordModel.monthNamesBn[month - 1]} $year';
}

class SelectedMonthYearNotifier extends Notifier<MonthYearState> {
  @override
  MonthYearState build() {
    final now = DateTime.now();
    return MonthYearState(month: now.month, year: now.year);
  }

  void previousMonth() {
    if (state.month == 1) {
      state = MonthYearState(month: 12, year: state.year - 1);
    } else {
      state = MonthYearState(month: state.month - 1, year: state.year);
    }
  }

  void nextMonth() {
    if (state.month == 12) {
      state = MonthYearState(month: 1, year: state.year + 1);
    } else {
      state = MonthYearState(month: state.month + 1, year: state.year);
    }
  }

  void setMonthYear(int month, int year) {
    state = MonthYearState(month: month, year: year);
  }
}

final selectedFeeMonthYearProvider =
    NotifierProvider<SelectedMonthYearNotifier, MonthYearState>(
  SelectedMonthYearNotifier.new,
);

// ── Monthly Fees Notifier ───────────────────────────────────────
class MonthlyFeesNotifier extends AsyncNotifier<List<FeeRecordModel>> {
  @override
  Future<List<FeeRecordModel>> build() async {
    final my = ref.watch(selectedFeeMonthYearProvider);
    final repo = ref.watch(feeRepositoryProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);

    // Auto-initialize fees for active students if available
    final students = studentsAsync.value ?? [];
    if (students.isNotEmpty) {
      await repo.initializeMonthFees(
        students: students,
        month: my.month,
        year: my.year,
      );
    }

    return await repo.fetchFeesForMonth(month: my.month, year: my.year);
  }

  /// Records or updates payment for a student
  Future<bool> recordPayment({
    required String studentId,
    required double totalAmount,
    required double paidAmount,
    String? note,
  }) async {
    final my = ref.read(selectedFeeMonthYearProvider);
    final repo = ref.read(feeRepositoryProvider);

    try {
      await repo.recordPayment(
        studentId: studentId,
        month: my.month,
        year: my.year,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        note: note,
      );
      ref.invalidateSelf();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sends a fee due reminder SMS to the guardian
  Future<bool> sendDueReminderSms({
    required StudentModel student,
    required double dueAmount,
  }) async {
    final my = ref.read(selectedFeeMonthYearProvider);
    final coaching = ref.read(coachingNameProvider);

    return await SmsService.sendFeeDueSms(
      guardianPhone: student.parentPhone,
      studentName: student.fullName,
      dueAmount: dueAmount,
      monthYear: my.displayBn,
      customCoachingName: coaching,
    );
  }
}

final monthlyFeesProvider =
    AsyncNotifierProvider<MonthlyFeesNotifier, List<FeeRecordModel>>(
  MonthlyFeesNotifier.new,
);
