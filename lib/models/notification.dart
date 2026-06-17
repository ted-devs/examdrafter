import 'package:cloud_firestore/cloud_firestore.dart';

class SystemNotification {
  final String id;
  final String targetUid;
  final String title;
  final String message;
  final String type; // e.g. 'exam_commissioned' | 'quota_delegated' | 'question_submitted' | 'curation_finalized' | 'exam_approved' | 'exam_rejected' | 'extension_requested' | 'extension_decided' | 'general'
  final String? relatedRequestId;
  final DateTime createdAt;

  SystemNotification({
    required this.id,
    required this.targetUid,
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
      targetUid: data['targetUid'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      relatedRequestId: data['relatedRequestId'],
      createdAt: parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetUid': targetUid,
      'title': title,
      'message': message,
      'type': type,
      if (relatedRequestId != null) 'relatedRequestId': relatedRequestId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
