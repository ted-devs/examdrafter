import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';

class DraftService {
  DraftService._privateConstructor();
  static final DraftService _instance = DraftService._privateConstructor();
  factory DraftService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves a question to Firestore.
  /// If it is a revision of an approved question, it clones it, increments the version,
  /// links to the old question via `previousVersionId`, and deprecates the old question.
  Future<void> saveQuestion({
    required Question question,
    required bool submit,
    required bool isRevision,
  }) async {
    final status = submit ? 'submitted' : 'draft';

    if (isRevision && question.status == 'approved') {
      final docRef = _firestore.collection('questions').doc();
      
      final newVersion = Question(
        id: docRef.id,
        sourceDraftId: question.sourceDraftId,
        version: question.version + 1,
        questionText: question.questionText,
        options: question.options,
        topics: question.topics,
        difficulty: question.difficulty,
        courseId: question.courseId,
        authorUid: question.authorUid,
        status: status,
        previousVersionId: question.id,
        errorDoNotUse: false,
        createdAt: question.createdAt,
        updatedAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      
      // Deprecate the old approved question in the pool
      batch.update(_firestore.collection('questions').doc(question.id), {
        'status': 'deprecated',
        'errorDoNotUse': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Save the new version
      batch.set(docRef, newVersion.toMap());

      // If the old question was selected in the curation list, replace it
      final curationDoc = await _firestore.collection('curations').doc(question.sourceDraftId).get();
      if (curationDoc.exists) {
        final data = curationDoc.data()!;
        final rawSelected = data['selectedQuestionIds'] as List? ?? [];
        final selectedList = rawSelected.map((e) => e.toString()).toList();
        if (selectedList.contains(question.id)) {
          selectedList.remove(question.id);
          selectedList.add(docRef.id);
          batch.update(_firestore.collection('curations').doc(question.sourceDraftId), {
            'selectedQuestionIds': selectedList,
          });
        }
      }

      await batch.commit();
    } else {
      // Regular insert or update
      if (question.id.isEmpty) {
        final docRef = _firestore.collection('questions').doc();
        final newQ = Question(
          id: docRef.id,
          sourceDraftId: question.sourceDraftId,
          version: 1,
          questionText: question.questionText,
          options: question.options,
          topics: question.topics,
          difficulty: question.difficulty,
          courseId: question.courseId,
          authorUid: question.authorUid,
          status: status,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await docRef.set(newQ.toMap());
      } else {
        await _firestore.collection('questions').doc(question.id).update({
          'questionText': question.questionText,
          'options': question.options.map((o) => o.toMap()).toList(),
          'difficulty': question.difficulty,
          'topics': question.topics,
          'status': status,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }

  /// Recalls a submitted question back to draft status so the teacher can edit it.
  Future<void> recallToDraft(String questionId) async {
    await _firestore.collection('questions').doc(questionId).update({
      'status': 'draft',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
