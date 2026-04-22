import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final bool active;
  final bool deleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.active,
    this.deleted = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == 'admin';

  bool get canSignIn => active && !deleted;

  String get roleLabel => isAdmin ? 'Admin' : 'Nhân viên';

  String get statusLabel {
    if (deleted) return 'Đã xóa mềm';
    if (!active) return 'Đang khóa';
    return 'Đang hoạt động';
  }

  String get displayLabel {
    final name = displayName.trim();
    if (name.isNotEmpty) return name;
    return email;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'active': active,
      'deleted': deleted,
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      role: map['role']?.toString() == 'admin' ? 'admin' : 'user',
      active: map['active'] != false,
      deleted: map['deleted'] == true,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}
