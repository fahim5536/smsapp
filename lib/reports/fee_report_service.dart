import 'package:intl/intl.dart';

import '../models/fee_record_model.dart';
import '../models/student_model.dart';

/// Service class for generating fee collection reports
class FeeReportService {
  /// Generate a monthly fee collection report
  static Map<String, dynamic> generateMonthlyReport({
    required List<FeeRecordModel> feeRecords,
    required List<StudentModel> students,
    required int month,
    required int year,
  }) {
    // Only records that belong to the requested month/year.
    final records = feeRecords
        .where((f) => f.month == month && f.year == year)
        .toList();

    // Calculate aggregate statistics
    double totalBilled = 0;
    double totalCollected = 0;
    int dueCount = 0;
    int paidCount = 0;

    for (final f in records) {
      totalBilled += f.amount;
      totalCollected += f.paidAmount;
      if (f.isFullyPaid) {
        paidCount++;
      } else {
        dueCount++;
      }
    }
    final totalDue = (totalBilled - totalCollected)
        .clamp(0.0, double.infinity)
        .toDouble();

    StudentModel unknownStudent(String grade) => StudentModel(
          id: '',
          fullName: 'অজানা',
          grade: grade,
          subject: '',
          parentPhone: '',
          monthlyFee: 0,
          admissionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    // Due students details
    final dueStudents = <Map<String, dynamic>>[];
    for (final f in records.where((f) => !f.isFullyPaid)) {
      final student = students.firstWhere(
        (s) => s.id == f.studentId,
        orElse: () => unknownStudent(''),
      );
      dueStudents.add({
        'studentName': student.fullName,
        'grade': student.grade,
        'dueAmount': f.dueAmount,
        'paidAmount': f.paidAmount,
        'totalAmount': f.amount,
      });
    }

    // Paid students summary
    final paidStudents = <Map<String, dynamic>>[];
    for (final f in records.where((f) => f.isFullyPaid)) {
      final student = students.firstWhere(
        (s) => s.id == f.studentId,
        orElse: () => unknownStudent(''),
      );
      paidStudents.add({
        'studentName': student.fullName,
        'grade': student.grade,
        'totalAmount': f.amount,
        'paidAmount': f.paidAmount,
      });
    }

    // Payment summary by grade
    final gradeWise = <String, Map<String, dynamic>>{};
    for (final f in records) {
      final student = students.firstWhere(
        (s) => s.id == f.studentId,
        orElse: () => unknownStudent('অজানা'),
      );
      final grade = student.grade;
      if (gradeWise[grade] == null) {
        gradeWise[grade] = {
          'totalBilled': 0.0,
          'totalCollected': 0.0,
          'dueCount': 0,
          'paidCount': 0,
          'studentCount': 0,
        };
      }
      final g = gradeWise[grade]!;
      g['totalBilled'] = (g['totalBilled'] as double) + f.amount;
      g['totalCollected'] = (g['totalCollected'] as double) + f.paidAmount;
      if (f.isFullyPaid) {
        g['paidCount'] = (g['paidCount'] as int) + 1;
      } else {
        g['dueCount'] = (g['dueCount'] as int) + 1;
      }
      g['studentCount'] = (g['studentCount'] as int) + 1;
    }

    return {
      'month': month,
      'year': year,
      'displayBn': '${_getMonthName(month)} $year',
      'totalBilled': totalBilled,
      'totalCollected': totalCollected,
      'totalDue': totalDue,
      'dueCount': dueCount,
      'paidCount': paidCount,
      'collectionRate': totalBilled > 0
          ? (totalCollected / totalBilled * 100)
          : 0.0,
      'dueStudents': dueStudents,
      'paidStudents': paidStudents,
      'gradeWise': gradeWise,
      'generatedAt': DateTime.now(),
    };
  }

  /// Generate a yearly fee summary report
  static Map<String, dynamic> generateYearlyReport({
    required List<FeeRecordModel> feeRecords,
    required List<StudentModel> students,
    required int year,
  }) {
    // Group by month, using each record's parsed month/year.
    final monthlyData = <int, Map<String, dynamic>>{};

    for (int month = 1; month <= 12; month++) {
      monthlyData[month] = generateMonthlyReport(
        feeRecords: feeRecords,
        students: students,
        month: month,
        year: year,
      );
    }

    // Calculate yearly totals
    double yearlyBilled = 0;
    double yearlyCollected = 0;
    int yearlyDueCount = 0;
    int yearlyPaidCount = 0;

    for (final monthData in monthlyData.values) {
      yearlyBilled += monthData['totalBilled'] as double;
      yearlyCollected += monthData['totalCollected'] as double;
      yearlyDueCount += monthData['dueCount'] as int;
      yearlyPaidCount += monthData['paidCount'] as int;
    }
    final yearlyDue =
        (yearlyBilled - yearlyCollected).clamp(0.0, double.infinity).toDouble();

    return {
      'year': year,
      'displayBn': '$year সালের বার্ষিক রিপোর্ট',
      'monthlyData': monthlyData,
      'yearlyBilled': yearlyBilled,
      'yearlyCollected': yearlyCollected,
      'yearlyDue': yearlyDue,
      'yearlyDueCount': yearlyDueCount,
      'yearlyPaidCount': yearlyPaidCount,
      'yearlyCollectionRate': yearlyBilled > 0
          ? (yearlyCollected / yearlyBilled * 100)
          : 0.0,
      'generatedAt': DateTime.now(),
    };
  }

  /// Get Bangla month name
  static String _getMonthName(int month) {
    const monthNames = [
      'জানুয়ারি',
      'ফেব্রুয়ারি',
      'মার্চ',
      'এপ্রিল',
      'মে',
      'জুন',
      'জুলাই',
      'আগস্ট',
      'সেপ্টেম্বর',
      'অক্টোবর',
      'নভেম্বর',
      'ডিসেম্বর',
    ];
    return (month >= 1 && month <= 12) ? monthNames[month - 1] : '';
  }

  /// Format currency for report
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return formatter.format(amount);
  }

  /// Get due students summary text
  static String getDueSummary(int dueCount, int totalStudents) {
    if (dueCount == 0) {
      return 'এই মাসে কোনো বকেয়া নেই! 🎉';
    }
    if (totalStudents <= 0) {
      return '$dueCount জন শিক্ষার্থীর বকেয়া রয়েছে';
    }
    final percentage = (dueCount / totalStudents * 100).toStringAsFixed(1);
    return '$dueCount/$totalStudents শিক্ষার্থী ($percentage%) বকেয়া রয়েছে';
  }

  /// Get collection rate text
  static String getCollectionRateText(double collectionRate) {
    if (collectionRate >= 100) {
      return 'সম্পূর্ণ আদায় সম্পন্ন! 🎉';
    }
    return '${collectionRate.toStringAsFixed(1)}% আদায় হয়েছে';
  }
}
