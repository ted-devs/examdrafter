import 'package:cloud_firestore/cloud_firestore.dart';

class ExtensionRequest {
  final String id;
  final String examRequestId;
  final String courseId;
  final String requestedByUid;
  final DateTime currentDeadline;
  final DateTime requestedDeadline;
  final String reason;
  final String status; // 'pending' | 'approved' | 'rejected'

  ExtensionRequest({
    required this.id,
    required this.examRequestId,
    required this.courseId,
    required this.requestedByUid,
    required this.currentDeadline,
    required this.requestedDeadline,
    required this.reason,
    required this.status,
  });

  factory ExtensionRequest.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return ExtensionRequest(
      id: id,
      examRequestId: data['examRequestId'] ?? '',
      courseId: data['courseId'] ?? '',
      requestedByUid: data['requestedByUid'] ?? '',
      currentDeadline: parseDateTime(data['currentDeadline']),
      requestedDeadline: parseDateTime(data['requestedDeadline']),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'examRequestId': examRequestId,
      'courseId': courseId,
      'requestedByUid': requestedByUid,
      'currentDeadline': Timestamp.fromDate(currentDeadline),
      'requestedDeadline': Timestamp.fromDate(requestedDeadline),
      'reason': reason,
      'status': status,
    };
  }
}
