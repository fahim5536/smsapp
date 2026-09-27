/// Attendance status enum matching Supabase `attendance` table status
enum AttendanceStatus {
  present('Present', 'উপস্থিত', 0xFF2ECC71),
  absent('Absent', 'অনুপস্থিত', 0xFFE74C3C),
  late('Late', 'বিলম্ব', 0xFFF39C12),
  excused('Excused', 'ছুটি', 0xFF3498DB);

  final String value;
  final String labelBn;
  final int colorValue;

  const AttendanceStatus(this.value, this.labelBn, this.colorValue);

  static AttendanceStatus fromString(String value) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => AttendanceStatus.present,
    );
  }
}

/// Represents an attendance entry in the Supabase `attendance` table.
class AttendanceModel {
  final String id;
  final String? teacherId;
  final String studentId;
  final DateTime date;
  final AttendanceStatus status;
  final String? note;
  final DateTime createdAt;

  const AttendanceModel({
    required this.id,
    this.teacherId,
    required this.studentId,
    required this.date,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: (json['id'] ?? '') as String,
      teacherId: json['teacher_id'] as String?,
      studentId: (json['student_id'] ?? '') as String,
      date: DateTime.parse(json['date'] as String),
      status: AttendanceStatus.fromString(json['status'] as String? ?? 'Present'),
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    final map = <String, dynamic>{
      'student_id': studentId,
      'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'status': status.value,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  AttendanceModel copyWith({
    String? id,
    String? teacherId,
    String? studentId,
    DateTime? date,
    AttendanceStatus? status,
    String? note,
    DateTime? createdAt,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
