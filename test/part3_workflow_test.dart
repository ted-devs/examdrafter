import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:examdrafter/models/question.dart';
import 'package:examdrafter/models/exam_request.dart';

// Business logic functions to test and document behavior
List<T> shuffleList<T>(List<T> list, Random random) {
  final result = List<T>.from(list);
  for (int i = result.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final temp = result[i];
    result[i] = result[j];
    result[j] = temp;
  }
  return result;
}

bool isTeacherNonCompliant({
  required DateTime internalDeadline,
  required int delegatedQuota,
  required int draftedCount,
  required DateTime currentTime,
}) {
  final isDeadlinePassed = currentTime.isAfter(internalDeadline);
  return isDeadlinePassed && draftedCount < delegatedQuota;
}

ExamRequest approveRequest(ExamRequest request, String semester, String year) {
  return ExamRequest(
    id: request.id,
    section: request.section,
    departmentId: request.departmentId,
    courseId: request.courseId,
    questionCount: request.questionCount,
    difficultyDistribution: request.difficultyDistribution,
    adminDeadline: request.adminDeadline,
    internalDeadline: request.internalDeadline,
    status: ExamRequestStatus.approved,
    revisionNotes: null,
    createdByUid: request.createdByUid,
    createdAt: request.createdAt,
    semester: semester,
    year: year,
  );
}

ExamRequest rejectRequest(ExamRequest request, String notes) {
  return ExamRequest(
    id: request.id,
    section: request.section,
    departmentId: request.departmentId,
    courseId: request.courseId,
    questionCount: request.questionCount,
    difficultyDistribution: request.difficultyDistribution,
    adminDeadline: request.adminDeadline,
    internalDeadline: request.internalDeadline,
    status: ExamRequestStatus.returnedForRevision,
    revisionNotes: notes,
    createdByUid: request.createdByUid,
    createdAt: request.createdAt,
  );
}

void main() {
  group('Part 3 Workflow: Shuffling, Compliance & Admin State Transitions', () {
    test('Set B Option Shuffling: preserves isCorrect answer mapping', () {
      final random = Random(42); // Seeded random for determinism

      final question = Question(
        id: 'q1',
        sourceDraftId: 'draft1',
        version: 1,
        questionText: 'What is 2 + 2?',
        options: [
          Option(text: '3', isCorrect: false),
          Option(text: '4', isCorrect: true), // Correct option
          Option(text: '5', isCorrect: false),
          Option(text: '6', isCorrect: false),
        ],
        topics: ['Math'],
        difficulty: 'Easy',
        courseId: 'math101',
        authorUid: 't1',
        status: 'approved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Perform option shuffle
      final shuffledOptions = shuffleList(question.options, random);

      expect(shuffledOptions.length, 4);

      // Ensure that the option with text '4' remains the ONLY correct option
      final correctOption = shuffledOptions.firstWhere((opt) => opt.isCorrect);
      expect(correctOption.text, '4');

      final correctCount = shuffledOptions.where((opt) => opt.isCorrect).length;
      expect(correctCount, 1);

      // Find the index of the correct option post-shuffle
      final correctIndex = shuffledOptions.indexOf(correctOption);
      expect(correctIndex >= 0 && correctIndex < 4, true);

      // The answer key resolves the letter dynamically
      final answerLetter = String.fromCharCode(65 + correctIndex);
      expect(answerLetter.isNotEmpty, true);
    });

    test('Teacher Compliance: flags overdue delegations with incomplete quota', () {
      final deadline = DateTime(2026, 6, 10, 12, 0);

      // Scenario A: Deadline not passed yet, quota not met (Compliant for now)
      final currentTimeA = DateTime(2026, 6, 10, 11, 0);
      expect(
        isTeacherNonCompliant(
          internalDeadline: deadline,
          delegatedQuota: 5,
          draftedCount: 3,
          currentTime: currentTimeA,
        ),
        false,
      );

      // Scenario B: Deadline passed, quota not met (Non-Compliant!)
      final currentTimeB = DateTime(2026, 6, 10, 13, 0);
      expect(
        isTeacherNonCompliant(
          internalDeadline: deadline,
          delegatedQuota: 5,
          draftedCount: 3,
          currentTime: currentTimeB,
        ),
        true,
      );

      // Scenario C: Deadline passed, quota met (Compliant!)
      expect(
        isTeacherNonCompliant(
          internalDeadline: deadline,
          delegatedQuota: 5,
          draftedCount: 5,
          currentTime: currentTimeB,
        ),
        false,
      );

      // Scenario D: Deadline passed, exceeded quota (Compliant!)
      expect(
        isTeacherNonCompliant(
          internalDeadline: deadline,
          delegatedQuota: 5,
          draftedCount: 6,
          currentTime: currentTimeB,
        ),
        false,
      );
    });

    test('Admin Transitions: Approve (with term tags) and Reject (with notes)', () {
      final initialRequest = ExamRequest(
        id: 'req_123',
        section: 'Sec A',
        departmentId: 'CS',
        courseId: 'CS101',
        questionCount: 10,
        difficultyDistribution: {'Easy': 5, 'Medium': 5},
        adminDeadline: DateTime.now().add(const Duration(days: 3)),
        status: ExamRequestStatus.submittedToAdmin,
        createdByUid: 'admin_1',
        createdAt: DateTime.now(),
      );

      // Approve state transition
      final approved = approveRequest(initialRequest, 'Fall', '2026');
      expect(approved.status, ExamRequestStatus.approved);
      expect(approved.semester, 'Fall');
      expect(approved.year, '2026');
      expect(approved.revisionNotes, null);

      // Reject state transition
      final rejected = rejectRequest(initialRequest, 'Difficulty distribution needs adjustment.');
      expect(rejected.status, ExamRequestStatus.returnedForRevision);
      expect(rejected.revisionNotes, 'Difficulty distribution needs adjustment.');
      expect(rejected.semester, null);
      expect(rejected.year, null);
    });
  });
}
