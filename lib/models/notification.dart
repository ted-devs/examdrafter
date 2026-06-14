import 'package:cloud_firestore/cloud_firestore.dart';

class SystemNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'deadline_missed' | 'extension_request' | 'general'
  final String? relatedRequestId;
  final DateTime createdAt;

  SystemNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.relatedRequestId,
    required this.createdAt,
  });

  factory SystemNotification.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return SystemNotification(
      id: id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      relatedRequestId: data['relatedRequestId'],
      createdAt: parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      if (relatedRequestId != null) 'relatedRequestId': relatedRequestId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
