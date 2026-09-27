/// Represents a class routine entry in the Supabase `routines` table.
class ClassRoutineModel {
  final String id;
  final String? teacherId;
  final String subject; // maps to 'class_name' or 'subject'
  final String? topic;
  final int dayOfWeek; // 1 = Mon ... 7 = Sun
  final String startTime;
  final String endTime;
  final String? location;
  final bool isActive;
  final DateTime createdAt;

  const ClassRoutineModel({
    required this.id,
    this.teacherId,
    required this.subject,
    this.topic,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.location,
    this.isActive = true,
    required this.createdAt,
  });

  static const List<String> dayNamesEn = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static const List<String> dayNamesBn = [
    'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'
  ];

  String get dayNameEn => (dayOfWeek >= 1 && dayOfWeek <= 7) ? dayNamesEn[dayOfWeek - 1] : '';
  String get dayNameBn => (dayOfWeek >= 1 && dayOfWeek <= 7) ? dayNamesBn[dayOfWeek - 1] : '';
  String get timeRange => '$startTime - $endTime';

  factory ClassRoutineModel.fromJson(Map<String, dynamic> json) {
    final rawDay = json['day']?.toString() ?? '';
    int parsedDay = 1;
    for (int i = 0; i < dayNamesBn.length; i++) {
      if (rawDay.contains(dayNamesBn[i]) || rawDay.toLowerCase().contains(dayNamesEn[i].toLowerCase())) {
        parsedDay = i + 1;
        break;
      }
    }
    if (json['day_of_week'] is int) {
      parsedDay = json['day_of_week'] as int;
    }

    final rawTime = (json['time'] ?? '').toString();
    String start = '10:00 AM';
    String end = '11:30 AM';
    if (rawTime.contains('-')) {
      final parts = rawTime.split('-');
      start = parts[0].trim();
      end = parts[1].trim();
    } else if (rawTime.isNotEmpty) {
      start = rawTime;
    }

    return ClassRoutineModel(
      id: (json['id'] ?? '') as String,
      teacherId: json['teacher_id'] as String?,
      subject: (json['class_name'] ?? json['subject'] ?? '') as String,
      topic: json['topic'] as String?,
      dayOfWeek: parsedDay,
      startTime: (json['start_time'] ?? start) as String,
      endTime: (json['end_time'] ?? end) as String,
      location: json['location'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    final map = <String, dynamic>{
      'class_name': subject,
      'day': dayNameBn,
      'time': timeRange,
      'topic': topic,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  ClassRoutineModel copyWith({
    String? id,
    String? teacherId,
    String? subject,
    String? topic,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? location,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ClassRoutineModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
