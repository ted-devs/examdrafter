import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherDelegation {
  final String teacherUid;
  final String courseId;
  final int questionCount;

  TeacherDelegation({
    required this.teacherUid,
    required this.courseId,
    required this.questionCount,
  });

  factory TeacherDelegation.fromMap(Map<String, dynamic> data) {
    return TeacherDelegation(
      teacherUid: data['teacherUid'] ?? '',
      courseId: data['courseId'] ?? '',
      questionCount: data['questionCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherUid': teacherUid,
      'courseId': courseId,
      'questionCount': questionCount,
    };
  }
}

class ExamCuration {
  final String examRequestId;
  final List<TeacherDelegation> teacherDelegations;
  final Map<String, List<String>> votes;
  final List<String> selectedQuestionIds;
  final String? finalizedByUid;
  final DateTime? finalizedAt;

  ExamCuration({
    required this.examRequestId,
    required this.teacherDelegations,
    required this.votes,
    required this.selectedQuestionIds,
    this.finalizedByUid,
    this.finalizedAt,
  });

  factory ExamCuration.fromMap(Map<String, dynamic> data, String id) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return null;
    }

    final rawDelegations = data['teacherDelegations'];
    final List<TeacherDelegation> parsedDelegations = [];
    if (rawDelegations is List) {
      for (final item in rawDelegations) {
        if (item is Map<String, dynamic>) {
          parsedDelegations.add(TeacherDelegation.fromMap(item));
        }
      }
    }

    final rawVotes = data['votes'];
    final Map<String, List<String>> parsedVotes = {};
    if (rawVotes is Map) {
      rawVotes.forEach((key, value) {
        final List<String> voters = [];
        if (value is List) {
          for (final voter in value) {
            voters.add(voter.toString());
          }
        }
        parsedVotes[key.toString()] = voters;
      });
    }

    final rawSelected = data['selectedQuestionIds'];
    final List<String> parsedSelected = [];
    if (rawSelected is List) {
      for (final item in rawSelected) {
        parsedSelected.add(item.toString());
      }
    }

    return ExamCuration(
      examRequestId: id,
      teacherDelegations: parsedDelegations,
      votes: parsedVotes,
      selectedQuestionIds: parsedSelected,
      finalizedByUid: data['finalizedByUid'],
      finalizedAt: data['finalizedAt'] != null ? parseDateTime(data['finalizedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherDelegations': teacherDelegations.map((d) => d.toMap()).toList(),
      'votes': votes,
      'selectedQuestionIds': selectedQuestionIds,
      if (finalizedByUid != null) 'finalizedByUid': finalizedByUid,
      if (finalizedAt != null) 'finalizedAt': Timestamp.fromDate(finalizedAt!),
    };
  }
}
