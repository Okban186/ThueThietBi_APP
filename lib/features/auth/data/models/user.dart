import 'package:thuethietbi_app/features/auth/data/models/staff.dart';

class User {
  const User({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    this.phone,
    this.avatarStorageFileId,
    this.status,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
    this.avatarUrl,
    this.roles = const [],
    this.staff, // Thêm staff vào constructor
  });

  final String id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarStorageFileId;
  final String? status;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> roles;
  final String? avatarUrl;
  final Staff? staff; // Khai báo thêm trường staff (có thể null nếu user đó không phải nhân viên)

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    avatarStorageFileId: json['avatarStorageFileId'] as String?,
    status: json['status'] as String?,
    lastLoginAt: _date(json['lastLoginAt']),
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    avatarUrl: json['avatarUrl'] as String?, // Bổ sung gán avatarUrl từ json
    roles: (json['roles'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    // Parse đối tượng staff nếu API trả về trường này
    staff: json['staff'] != null
        ? Staff.fromJson(json['staff'] as Map<String, dynamic>)
        : null,
  );

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);
}
