import 'package:cloud_firestore/cloud_firestore.dart';

enum ExamRequestStatus {
  commissioned,
  delegated,
  curating,
  submittedToAdmin,
  approved,
  returnedForRevision;

  String toJson() {
    switch (this) {
      case ExamRequestStatus.commissioned:
        return 'commissioned';
      case ExamRequestStatus.delegated:
        return 'delegated';
      case ExamRequestStatus.curating:
        return 'curating';
      case ExamRequestStatus.submittedToAdmin:
        return 'submitted_to_admin';
      case ExamRequestStatus.approved:
        return 'approved';
      case ExamRequestStatus.returnedForRevision:
        return 'returned_for_revision';
    }
  }

  static ExamRequestStatus fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'commissioned':
        return ExamRequestStatus.commissioned;
      case 'delegated':
        return ExamRequestStatus.delegated;
      case 'curating':
        return ExamRequestStatus.curating;
      case 'submitted_to_admin':
        return ExamRequestStatus.submittedToAdmin;
      case 'approved':
        return ExamRequestStatus.approved;
      case 'returned_for_revision':
        return ExamRequestStatus.returnedForRevision;
      default:
        return ExamRequestStatus.commissioned;
    }
  }
}

class ExamRequest {
  final String id;
  final String section;
  final String departmentId;
  final String courseId;
  final int questionCount;
  final Map<String, int> difficultyDistribution;
  final DateTime adminDeadline;
  final DateTime? internalDeadline;
  final ExamRequestStatus status;
  final String? revisionNotes;
  final String createdByUid;
  final DateTime createdAt;

  ExamRequest({
    required this.id,
    required this.section,
    required this.departmentId,
    required this.courseId,
    required this.questionCount,
    required this.difficultyDistribution,
    required this.adminDeadline,
    this.internalDeadline,
    required this.status,
    this.revisionNotes,
    required this.createdByUid,
    required this.createdAt,
  });

  factory ExamRequest.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    final rawDiffDist = data['difficultyDistribution'];
    final Map<String, int> parsedDiffDist = {};
    if (rawDiffDist is Map) {
      rawDiffDist.forEach((key, value) {
        parsedDiffDist[key.toString()] = int.tryParse(value.toString()) ?? 0;
      });
    }

    return ExamRequest(
      id: id,
      section: data['section'] ?? '',
      departmentId: data['departmentId'] ?? '',
      courseId: data['courseId'] ?? '',
      questionCount: data['questionCount'] ?? 0,
      difficultyDistribution: parsedDiffDist,
      adminDeadline: parseDateTime(data['adminDeadline']),
      internalDeadline: data['internalDeadline'] != null ? parseDateTime(data['internalDeadline']) : null,
      status: ExamRequestStatus.fromJson(data['status'] ?? 'commissioned'),
      revisionNotes: data['revisionNotes'],
      createdByUid: data['createdByUid'] ?? '',
      createdAt: parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'section': section,
      'departmentId': departmentId,
      'courseId': courseId,
      'questionCount': questionCount,
      'difficultyDistribution': difficultyDistribution,
      'adminDeadline': Timestamp.fromDate(adminDeadline),
      if (internalDeadline != null) 'internalDeadline': Timestamp.fromDate(internalDeadline!),
      'status': status.toJson(),
      if (revisionNotes != null) 'revisionNotes': revisionNotes,
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
