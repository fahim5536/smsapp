/// Fee status enum matching Supabase `fees` table status
enum FeeStatus {
  unpaid('Due', 'বকেয়া', 0xFFE74C3C),
  partial('Partial', 'আংশিক পরিশোধ', 0xFFF39C12),
  paid('Paid', 'পরিশোধিত', 0xFF2ECC71);

  final String value;
  final String labelBn;
  final int colorValue;

  const FeeStatus(this.value, this.labelBn, this.colorValue);

  static FeeStatus fromString(String value) {
    return FeeStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => FeeStatus.unpaid,
    );
  }
}

/// Represents a monthly fee record in the Supabase `fees` table.
class FeeRecordModel {
  final String id;
  final String? teacherId;
  final String studentId;
  final int month; // 1-12
  final int year;
  final double amount;
  final double paidAmount;
  final FeeStatus status;
  final DateTime? paidDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeeRecordModel({
    required this.id,
    this.teacherId,
    required this.studentId,
    required this.month,
    required this.year,
    required this.amount,
    this.paidAmount = 0,
    this.status = FeeStatus.unpaid,
    this.paidDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Remaining unpaid / due amount
  double get dueAmount => (amount - paidAmount).clamp(0, double.infinity);

  /// Whether the fee is fully paid
  bool get isFullyPaid => status == FeeStatus.paid || dueAmount <= 0;

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> monthNamesBn = [
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
  ];

  String get monthName => (month >= 1 && month <= 12) ? monthNames[month - 1] : '';
  String get monthNameBn => (month >= 1 && month <= 12) ? monthNamesBn[month - 1] : '';
  String get periodDisplay => '$monthNameBn $year';

  factory FeeRecordModel.fromJson(Map<String, dynamic> json) {
    // Parses month format: e.g. "2026-09" or "September 2026" or "9"
    final rawMonth = json['month']?.toString() ?? '';
    int parsedMonth = DateTime.now().month;
    int parsedYear = DateTime.now().year;

    if (rawMonth.contains('-')) {
      final parts = rawMonth.split('-');
      parsedYear = int.tryParse(parts[0]) ?? parsedYear;
      parsedMonth = int.tryParse(parts[1]) ?? parsedMonth;
    } else {
      for (int i = 0; i < monthNames.length; i++) {
        if (rawMonth.toLowerCase().contains(monthNames[i].toLowerCase()) ||
            rawMonth.contains(monthNamesBn[i])) {
          parsedMonth = i + 1;
          break;
        }
      }
    }

    final totalAmount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final feeStatus = FeeStatus.fromString(json['status']?.toString() ?? 'Due');
    final paidAmount = feeStatus == FeeStatus.paid ? totalAmount : 0.0;

    return FeeRecordModel(
      id: (json['id'] ?? '') as String,
      teacherId: json['teacher_id'] as String?,
      studentId: (json['student_id'] ?? '') as String,
      month: parsedMonth,
      year: parsedYear,
      amount: totalAmount,
      paidAmount: paidAmount,
      status: feeStatus,
      paidDate: json['paid_date'] != null
          ? DateTime.tryParse(json['paid_date'] as String)
          : null,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    final map = <String, dynamic>{
      'student_id': studentId,
      'month': '$year-${month.toString().padLeft(2, '0')}',
      'amount': amount,
      'status': status.value,
      'paid_date': paidDate?.toIso8601String(),
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  FeeRecordModel copyWith({
    String? id,
    String? teacherId,
    String? studentId,
    int? month,
    int? year,
    double? amount,
    double? paidAmount,
    FeeStatus? status,
    DateTime? paidDate,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeeRecordModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      month: month ?? this.month,
      year: year ?? this.year,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      paidDate: paidDate ?? this.paidDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
