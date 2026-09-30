/// Represents a student record matching the Supabase `students` table.
class StudentModel {
  final String id;
  final String? teacherId;
  final String fullName; // maps to 'name' or 'full_name'
  final String? phone;
  final String? parentName;
  final String parentPhone; // maps to 'guardian_phone' or 'parent_phone'
  final String? address;
  final String grade; // maps to 'class_name' or 'grade'
  final String subject;
  final double monthlyFee; // maps to 'monthly_fee'
  final String? schedule;
  final DateTime admissionDate;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentModel({
    required this.id,
    this.teacherId,
    required this.fullName,
    this.phone,
    this.parentName,
    required this.parentPhone,
    this.address,
    required this.grade,
    required this.subject,
    required this.monthlyFee,
    this.schedule,
    required this.admissionDate,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Deserialize from Supabase response (supports both schemas) ────
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: (json['id'] ?? '') as String,
      teacherId: json['teacher_id'] as String?,
      fullName: (json['name'] ?? json['full_name'] ?? '') as String,
      phone: json['phone'] as String?,
      parentName: json['parent_name'] as String?,
      parentPhone: (json['guardian_phone'] ?? json['parent_phone'] ?? '') as String,
      address: json['address'] as String?,
      grade: (json['class_name'] ?? json['grade'] ?? '') as String,
      subject: (json['subject'] ?? '') as String,
      monthlyFee: (json['monthly_fee'] as num?)?.toDouble() ?? 0.0,
      schedule: json['schedule'] as String?,
      admissionDate: json['admission_date'] != null
          ? DateTime.parse(json['admission_date'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  // ── Serialize for INSERT / UPDATE ─────────────────────────
  // Matches Supabase `students` table. Null fields are omitted so a
  // partial edit never wipes existing database values.
  Map<String, dynamic> toJson() => {
        if (teacherId != null) 'teacher_id': teacherId,
        'name': fullName,
        if (phone != null) 'phone': phone,
        if (parentName != null) 'parent_name': parentName,
        'guardian_phone': parentPhone,
        if (address != null) 'address': address,
        'class_name': grade,
        'subject': subject,
        'monthly_fee': monthlyFee,
        if (schedule != null) 'schedule': schedule,
        'admission_date':
            '${admissionDate.year.toString().padLeft(4, '0')}-${admissionDate.month.toString().padLeft(2, '0')}-${admissionDate.day.toString().padLeft(2, '0')}',
        'is_active': isActive,
        if (notes != null) 'notes': notes,
      };

  // ── Immutable copy ─────────────────────────────────────────
  StudentModel copyWith({
    String? id,
    String? teacherId,
    String? fullName,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? address,
    String? grade,
    String? subject,
    double? monthlyFee,
    String? schedule,
    DateTime? admissionDate,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      StudentModel(
        id: id ?? this.id,
        teacherId: teacherId ?? this.teacherId,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        parentName: parentName ?? this.parentName,
        parentPhone: parentPhone ?? this.parentPhone,
        address: address ?? this.address,
        grade: grade ?? this.grade,
        subject: subject ?? this.subject,
        monthlyFee: monthlyFee ?? this.monthlyFee,
        schedule: schedule ?? this.schedule,
        admissionDate: admissionDate ?? this.admissionDate,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  // ── Initials for avatar fallback ───────────────────────────
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StudentModel && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'StudentModel(id: $id, name: $fullName, grade: $grade)';
}
