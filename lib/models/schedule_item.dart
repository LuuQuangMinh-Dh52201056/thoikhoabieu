class ScheduleItem {
  final String id;
  final DateTime date;
  final int startHour;
  final int endHour;
  final String teacherName;
  final String studentName;
  final String course;
  final String content;
  final String vehicle;
  final String assistantName;
  final String location;
  final String note;
  final String category;
  final String createdBy;
  final String createdByEmail;

  const ScheduleItem({
    required this.id,
    required this.date,
    required this.startHour,
    required this.endHour,
    required this.teacherName,
    required this.studentName,
    required this.course,
    required this.content,
    required this.vehicle,
    required this.assistantName,
    required this.location,
    required this.note,
    required this.category,
    this.createdBy = '',
    this.createdByEmail = '',
  });

  static const List<String> courses = ['C1', 'BSS', 'BTĐ'];
  static const List<String> categories = [
    'dat',
    'sa_hinh',
    'tap_xe',
    'tap_xe_chuan_bi_dat',
    'cabin',
    'off',
    'khac',
  ];

  static int _extractHour(dynamic raw, int fallback) {
    if (raw == null) return fallback;
    if (raw is int) return raw;
    final text = raw.toString();
    if (text.contains(':')) {
      return int.tryParse(text.split(':').first) ?? fallback;
    }
    return int.tryParse(text) ?? fallback;
  }

  static String normalizeCourse(String? value) {
    if (value != null && courses.contains(value)) return value;
    return 'C1';
  }

  static String normalizeCategory(String? value) {
    if (value != null && categories.contains(value)) return value;
    return 'sa_hinh';
  }

  static int normalizeStartHour(int value) {
    if (value < 7) return 7;
    if (value > 17) return 17;
    return value;
  }

  static int normalizeEndHour(int startHour, int value) {
    var end = value;
    if (end < 8) end = 8;
    if (end > 18) end = 18;
    if (end <= startHour) {
      end = startHour + 1;
      if (end > 18) end = 18;
    }
    return end;
  }

  String _formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  String get timeRange => '${_formatHour(startHour)} - ${_formatHour(endHour)}';

  int get durationHours => endHour - startHour;

  String get exportDate =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startHour': startHour,
      'endHour': endHour,
      'teacherName': teacherName,
      'studentName': studentName,
      'course': course,
      'content': content,
      'vehicle': vehicle,
      'assistantName': assistantName,
      'location': location,
      'note': note,
      'category': category,
      'createdBy': createdBy,
      'createdByEmail': createdByEmail,
    };
  }

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    final start = normalizeStartHour(
      _extractHour(map['startHour'] ?? map['startTime'], 7),
    );
    final end = normalizeEndHour(
      start,
      _extractHour(map['endHour'] ?? map['endTime'], start + 1),
    );

    return ScheduleItem(
      id: map['id']?.toString() ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      startHour: start,
      endHour: end,
      teacherName: map['teacherName']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      course: normalizeCourse(map['course']?.toString()),
      content: map['content']?.toString() ?? '',
      vehicle: map['vehicle']?.toString() ?? '',
      assistantName: map['assistantName']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      category: normalizeCategory(map['category']?.toString()),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByEmail: map['createdByEmail']?.toString() ?? '',
    );
  }

  ScheduleItem copyWith({
    String? id,
    DateTime? date,
    int? startHour,
    int? endHour,
    String? teacherName,
    String? studentName,
    String? course,
    String? content,
    String? vehicle,
    String? assistantName,
    String? location,
    String? note,
    String? category,
    String? createdBy,
    String? createdByEmail,
  }) {
    final nextStart = normalizeStartHour(startHour ?? this.startHour);
    return ScheduleItem(
      id: id ?? this.id,
      date: date ?? this.date,
      startHour: nextStart,
      endHour: normalizeEndHour(nextStart, endHour ?? this.endHour),
      teacherName: teacherName ?? this.teacherName,
      studentName: studentName ?? this.studentName,
      course: normalizeCourse(course ?? this.course),
      content: content ?? this.content,
      vehicle: vehicle ?? this.vehicle,
      assistantName: assistantName ?? this.assistantName,
      location: location ?? this.location,
      note: note ?? this.note,
      category: normalizeCategory(category ?? this.category),
      createdBy: createdBy ?? this.createdBy,
      createdByEmail: createdByEmail ?? this.createdByEmail,
    );
  }
}
