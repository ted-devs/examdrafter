import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/question_draft.dart';

/// Simple Firestore adapter for the exam draft flows.
/// Note: this is scaffolding for integration; the app still works in-memory.
class FirestoreService {
  FirestoreService._private();
  static final FirestoreService _instance = FirestoreService._private();
  factory FirestoreService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveDraft(String examId, QuestionDraft draft) async {
    final ref = _db
        .collection('exam_requests')
        .doc(examId)
        .collection('review_pool')
        .doc(draft.id);
    await ref.set({
      'teacherId': draft.teacherId,
      'questionText': draft.questionText,
      'options': draft.options
          .map((o) => {'text': o.text, 'isCorrect': o.isCorrect})
          .toList(),
      'topics': draft.topics,
      'difficulty': draft.difficulty,
      'status': draft.status,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> submitDraft(String examId, String draftId) async {
    final ref = _db
        .collection('exam_requests')
        .doc(examId)
        .collection('review_pool')
        .doc(draftId);
    await ref.update({
      'status': 'submitted',
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addReviewVote(
    String examId,
    String draftId,
    String voterId,
    String vote, {
    bool isTieBreaker = false,
  }) async {
    final votesRef = _db
        .collection('exam_requests')
        .doc(examId)
        .collection('review_pool')
        .doc(draftId)
        .collection('review_votes');
    await votesRef.doc(voterId).set({
      'voterId': voterId,
      'vote': vote,
      'isTieBreaker': isTieBreaker,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> promoteToQuestionBank(String examId, QuestionDraft draft) async {
    final bankRef = _db.collection('question_bank').doc();
    await bankRef.set({
      'sourceDraftId': draft.id,
      'questionText': draft.questionText,
      'options': draft.options
          .map((o) => {'text': o.text, 'isCorrect': o.isCorrect})
          .toList(),
      'topics': draft.topics,
      'difficulty': draft.difficulty,
      'createdAt': FieldValue.serverTimestamp(),
      'locked': true,
    });
  }

  Future<void> assignTeacherQuota(
    String examId,
    TeacherQuota quota,
  ) async {
    final quotaRef = _db
        .collection('exam_requests')
        .doc(examId)
        .collection('teacher_quotas')
        .doc(quota.id);
    await quotaRef.set({
      'teacherId': quota.teacherId,
      'teacherName': quota.teacherName,
      'courseId': quota.courseId,
      'courseName': quota.courseName,
      'quotaCount': quota.quotaCount,
      'submittedCount': quota.submittedCount,
      'status': quota.status,
      'deadline': quota.deadline,
      'assignedBy': quota.assignedBy,
      'notes': quota.notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
