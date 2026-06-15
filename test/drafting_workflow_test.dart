import 'package:flutter_test/flutter_test.dart';
import 'package:examdrafter/models/question.dart';

// Helper functions matching workflow rules to verify
bool isTimelineValid(DateTime adminDeadline, DateTime internalDeadline) {
  final cutoff = adminDeadline.subtract(const Duration(hours: 24));
  return internalDeadline.isBefore(cutoff) || internalDeadline.isAtSameMomentAs(cutoff);
}

bool validateQuestionOptions(List<Option> options) {
  if (options.length < 4 || options.length > 5) return false;
  final correctCount = options.where((o) => o.isCorrect).length;
  return correctCount == 1;
}

void main() {
  group('Drafting & Curation Workflow Business Logic Tests', () {
    test('Timeline validation: internal deadline must be >= 24h prior to admin deadline', () {
      final adminDeadline = DateTime(2026, 6, 12, 12, 0);

      // Valid: exactly 24 hours prior
      final validExact = adminDeadline.subtract(const Duration(hours: 24));
      expect(isTimelineValid(adminDeadline, validExact), true);

      // Valid: 48 hours prior
      final validEarly = adminDeadline.subtract(const Duration(hours: 48));
      expect(isTimelineValid(adminDeadline, validEarly), true);

      // Invalid: 12 hours prior (too late)
      final invalidLate = adminDeadline.subtract(const Duration(hours: 12));
      expect(isTimelineValid(adminDeadline, invalidLate), false);

      // Invalid: same moment as admin deadline
      expect(isTimelineValid(adminDeadline, adminDeadline), false);
    });

    test('MCQ Options validation: must have 4 or 5 options with exactly 1 correct option', () {
      // Valid: 4 options, 1 correct
      final validFour = [
        Option(text: 'A', isCorrect: true),
        Option(text: 'B', isCorrect: false),
        Option(text: 'C', isCorrect: false),
        Option(text: 'D', isCorrect: false),
      ];
      expect(validateQuestionOptions(validFour), true);

      // Valid: 5 options, 1 correct
      final validFive = [
        Option(text: 'A', isCorrect: false),
        Option(text: 'B', isCorrect: false),
        Option(text: 'C', isCorrect: false),
        Option(text: 'D', isCorrect: true),
        Option(text: 'E', isCorrect: false),
      ];
      expect(validateQuestionOptions(validFive), true);

      // Invalid: 3 options (too few)
      final invalidThree = [
        Option(text: 'A', isCorrect: true),
        Option(text: 'B', isCorrect: false),
        Option(text: 'C', isCorrect: false),
      ];
      expect(validateQuestionOptions(invalidThree), false);

      // Invalid: 6 options (too many)
      final invalidSix = [
        Option(text: 'A', isCorrect: true),
        Option(text: 'B', isCorrect: false),
        Option(text: 'C', isCorrect: false),
        Option(text: 'D', isCorrect: false),
        Option(text: 'E', isCorrect: false),
        Option(text: 'F', isCorrect: false),
      ];
      expect(validateQuestionOptions(invalidSix), false);

      // Invalid: 4 options, 2 correct
      final invalidTwoCorrect = [
        Option(text: 'A', isCorrect: true),
        Option(text: 'B', isCorrect: true),
        Option(text: 'C', isCorrect: false),
        Option(text: 'D', isCorrect: false),
      ];
      expect(validateQuestionOptions(invalidTwoCorrect), false);

      // Invalid: 4 options, 0 correct
      final invalidNoCorrect = [
        Option(text: 'A', isCorrect: false),
        Option(text: 'B', isCorrect: false),
        Option(text: 'C', isCorrect: false),
        Option(text: 'D', isCorrect: false),
      ];
      expect(validateQuestionOptions(invalidNoCorrect), false);
    });

    test('Question Version Control: editing an approved question clones it and increments version', () {
      final now = DateTime.now();
      final approvedQuestion = Question(
        id: 'q_approved_123',
        sourceDraftId: 'request_abc',
        version: 1,
        questionText: 'Approved original question text',
        options: [
          Option(text: 'A', isCorrect: true),
          Option(text: 'B', isCorrect: false),
          Option(text: 'C', isCorrect: false),
          Option(text: 'D', isCorrect: false),
        ],
        topics: ['topic_1'],
        difficulty: 'Easy',
        courseId: 'cs_101',
        authorUid: 'teacher_999',
        status: 'approved',
        createdAt: now,
        updatedAt: now,
      );

      // Create revised version
      final revisedQuestion = approvedQuestion.copyWithNewVersion(
        newQuestionText: 'Revised approved question text',
        newStatus: 'draft',
        newPreviousVersionId: approvedQuestion.id,
      );

      expect(revisedQuestion.id, ''); // Cloned question starts with an empty ID for Firestore to auto-generate
      expect(revisedQuestion.version, 2); // Version must increment by 1
      expect(revisedQuestion.previousVersionId, 'q_approved_123'); // Must point to the previous version
      expect(revisedQuestion.status, 'draft'); // Starts as draft status
      expect(revisedQuestion.questionText, 'Revised approved question text');
      expect(revisedQuestion.authorUid, approvedQuestion.authorUid); // Retains original author
      expect(revisedQuestion.courseId, approvedQuestion.courseId); // Retains same course ID
    });
  });
}
