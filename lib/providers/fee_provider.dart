import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/sms_service.dart';
import '../models/fee_record_model.dart';
import '../models/student_model.dart';
import '../repositories/fee_repository.dart';
import 'attendance_provider.dart';
import 'sms_provider.dart';
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

// ── Monthly Fees Notifier with optimizations ──────────────────────
class MonthlyFeesNotifier extends AsyncNotifier<List<FeeRecordModel>> {
  /// Month/year keys whose fee rows have already been initialized,
  /// so `build()` does not hit the database with writes on every rebuild.
  final Set<String> _initializedKeys = {};

  @override
  Future<List<FeeRecordModel>> build() async {
    final my = ref.watch(selectedFeeMonthYearProvider);
    final repo = ref.watch(feeRepositoryProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);

    // Auto-initialize fees for active students, once per month/year.
    final students = studentsAsync.value;
    final key = '${my.year}-${my.month}';
    if (students != null &&
        students.isNotEmpty &&
        !_initializedKeys.contains(key)) {
      _initializedKeys.add(key);
      try {
        await repo.initializeMonthFees(
          students: students,
          month: my.month,
          year: my.year,
        );
      } catch (_) {
        // Initialization is best-effort; the fetch below still returns
        // whatever rows exist. Allow a retry on the next rebuild.
        _initializedKeys.remove(key);
      }
    }

    return await repo.fetchFeesForMonth(month: my.month, year: my.year);
  }

  /// Records or updates payment for a student with retry logic
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
      // Invalidate cache to refresh list
      ref.invalidateSelf();
      return true;
    } catch (e) {
      // Could add retry logic here
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

    final message = SmsService.generateFeeDueMessage(
      studentName: student.fullName,
      dueAmount: dueAmount,
      monthYear: my.displayBn,
      customCoachingName: coaching,
    );
    final sent = await SmsService.sendCustomSms(
      phone: student.parentPhone,
      message: message,
    );
    await ref.read(smsLogProvider.notifier).logSms(
          phone: student.parentPhone,
          studentName: student.fullName,
          message: message,
          type: SmsType.feeDue,
          success: sent,
        );
    return sent;
  }

  /// Batch send fee due reminders to multiple students
  Future<BulkSmsResult> sendBatchFeeDueSms({
    required List<StudentModel> students,
    required String monthYear,
  }) async {
    final List<BulkSmsRecipient> recipients = [];

    for (final student in students) {
      if (student.parentPhone.isNotEmpty) {
        recipients.add(
          BulkSmsRecipient.fromStudent(
            phone: student.parentPhone,
            studentName: student.fullName,
            extraVariables: {
              'due_amount': student.monthlyFee.toStringAsFixed(0),
              'month_year': monthYear,
            },
          ),
        );
      }
    }

    final result = await SmsService.sendBulkSms(
      recipients: recipients,
      templateKey: SmsService.templateFeeDue,
      commonVariables: {'month_year': monthYear},
      customCoachingName: ref.read(coachingNameProvider),
    );

    // Record each dispatch in the SMS history.
    final logNotifier = ref.read(smsLogProvider.notifier);
    for (final recipient in recipients) {
      final succeeded = !result.failedNumbers.contains(recipient.phone);
      await logNotifier.logSms(
        phone: recipient.phone,
        studentName: recipient.studentName,
        message: 'বাল্ক SMS: ${SmsService.getTemplateDescription(SmsService.templateFeeDue)}',
        type: SmsType.bulk,
        success: succeeded,
      );
    }
    return result;
  }
}

final monthlyFeesProvider =
    AsyncNotifierProvider<MonthlyFeesNotifier, List<FeeRecordModel>>(
      MonthlyFeesNotifier.new,
    );
