class Notification {
  const Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.isRead,
    this.type,
    this.readAt,
    this.createdAt,
  });
  final String id, userId, title, content;
  final bool isRead;
  final String? type;
  final DateTime? readAt, createdAt;
  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      isRead: json['isRead'] as bool? ?? false,
      type: json['type'] as String?,
      readAt: _parseDate(json['readAt']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'isRead': isRead,
      'type': type,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  Notification copyWith({bool? isRead, DateTime? readAt}) {
    return Notification(
      id: id,
      userId: userId,
      title: title,
      content: content,
      isRead: isRead ?? this.isRead,
      type: type,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    return DateTime.parse(value as String);
  }
}
