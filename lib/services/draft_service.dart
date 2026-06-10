import '../models/question_bank.dart';
import '../models/question_draft.dart';
import 'firestore_service.dart';

/// A minimal in-memory service for drafts to use during UI implementation.
class DraftService {
  DraftService._privateConstructor();
  static final DraftService _instance = DraftService._privateConstructor();
  factory DraftService() => _instance;

  // Toggle persistent backup to Firestore when enabled and configured.
  bool useFirestore = false;
  String firestoreExamId = 'default_exam';

  final List<QuestionDraft> _drafts = [];
  final Map<String, List<ReviewRecord>> _reviewRecords = {};
  final List<QuestionBankItem> _questionBank = [];

  List<QuestionDraft> get drafts => List.unmodifiable(_drafts);

  List<QuestionDraft> get submittedDrafts => _drafts
      .where(
        (draft) => draft.status == 'submitted' || draft.status == 'in_review',
      )
      .toList();

  List<QuestionDraft> get approvedDrafts =>
      _drafts.where((draft) => draft.status == 'approved').toList();

  List<QuestionDraft> get rejectedDrafts =>
      _drafts.where((draft) => draft.status == 'rejected').toList();

  List<QuestionDraft> get recentDrafts => _drafts.reversed.take(6).toList();

  List<QuestionBankItem> get recentQuestionBankItems =>
      _questionBank.reversed.take(6).toList();

  List<ReviewRecord> reviewRecordsFor(String draftId) =>
      List.unmodifiable(_reviewRecords[draftId] ?? const []);

  List<QuestionBankItem> get questionBank => List.unmodifiable(_questionBank);

  int get totalVotes => _reviewRecords.values.fold<int>(
    0,
    (sum, records) => sum + records.length,
  );

  QuestionBankItem? getQuestionBankItem(String id) {
    try {
      return _questionBank.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  void saveDraft(QuestionDraft draft) {
    if (draft.id == null) {
      draft.id = DateTime.now().microsecondsSinceEpoch.toString();
      _drafts.add(draft);
    } else {
      final idx = _drafts.indexWhere((d) => d.id == draft.id);
      if (idx >= 0) _drafts[idx] = draft;
    }
    if (useFirestore) {
      try {
        FirestoreService().saveDraft(firestoreExamId, draft);
      } catch (_) {}
    }
  }

  void submitDraft(String id) {
    final idx = _drafts.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      _drafts[idx].status = 'submitted';
      if (useFirestore) {
        try {
          FirestoreService().submitDraft(firestoreExamId, id);
        } catch (_) {}
      }
    }
  }

  void addReviewVote({
    required String draftId,
    required String voterId,
    required ReviewVote vote,
    bool isCommitteeLead = false,
  }) {
    final draftIndex = _drafts.indexWhere((draft) => draft.id == draftId);
    if (draftIndex < 0) return;

    final votes = _reviewRecords.putIfAbsent(draftId, () => <ReviewRecord>[]);
    final existingVoteIndex = votes.indexWhere(
      (record) => record.voterId == voterId,
    );
    final record = ReviewRecord(
      voterId: voterId,
      vote: vote,
      isTieBreaker: false,
    );

    if (existingVoteIndex >= 0) {
      votes[existingVoteIndex] = record;
    } else {
      votes.add(record);
    }

    _drafts[draftIndex].status = 'in_review';
    if (useFirestore) {
      try {
        FirestoreService().addReviewVote(
          firestoreExamId,
          draftId,
          voterId,
          vote.toString().split('.').last,
          isTieBreaker: isCommitteeLead,
        );
      } catch (_) {}
    }
    _applyDecisionIfReady(
      draftId,
      leadVoterId: isCommitteeLead ? voterId : null,
    );
  }

  void _applyDecisionIfReady(String draftId, {String? leadVoterId}) {
    final draftIndex = _drafts.indexWhere((draft) => draft.id == draftId);
    if (draftIndex < 0) return;

    final votes = _reviewRecords[draftId] ?? const <ReviewRecord>[];
    final keepVotes = votes
        .where((record) => record.vote == ReviewVote.keep)
        .length;
    final dropVotes = votes
        .where((record) => record.vote == ReviewVote.drop)
        .length;
    final abstainVotes = votes
        .where((record) => record.vote == ReviewVote.abstain)
        .length;

    if (votes.isEmpty) return;

    final draft = _drafts[draftIndex];
    if (keepVotes > dropVotes) {
      draft.status = 'approved';
      draft.reviewedBy = 'committee';
      draft.committeeNote =
          'Approved by majority vote ($keepVotes keep, $dropVotes drop, $abstainVotes abstain).';
      // Promote to question bank on approval
      promoteToQuestionBank(draft);
      return;
    }

    if (dropVotes > keepVotes) {
      draft.status = 'rejected';
      draft.reviewedBy = 'committee';
      draft.committeeNote =
          'Rejected by majority vote ($dropVotes drop, $keepVotes keep, $abstainVotes abstain).';
      return;
    }

    if (leadVoterId != null) {
      final leadVote = votes.lastWhere(
        (record) => record.voterId == leadVoterId,
        orElse: () => ReviewRecord(voterId: '', vote: ReviewVote.abstain),
      );
      if (leadVote.voterId.isNotEmpty) {
        leadVote.isTieBreaker = true;
        if (leadVote.vote == ReviewVote.keep) {
          draft.status = 'approved';
          draft.reviewedBy = leadVoterId;
          draft.committeeNote = 'Approved by Committee Lead tie-breaker.';
          return;
        }
        if (leadVote.vote == ReviewVote.drop) {
          draft.status = 'rejected';
          draft.reviewedBy = leadVoterId;
          draft.committeeNote = 'Rejected by Committee Lead tie-breaker.';
          return;
        }
      }
    }

    draft.status = 'in_review';
    draft.reviewedBy = null;
    draft.committeeNote =
        'Waiting for a deciding vote or Committee Lead tie-breaker.';
  }

  void promoteToQuestionBank(QuestionDraft draft) {
    // create a new QuestionBankItem; determine version by existing sourceDraftId
    final sourceId = draft.id ?? '';
    final existing = _questionBank
        .where((q) => q.sourceDraftId == sourceId)
        .toList();
    final version = existing.isEmpty
        ? 1
        : (existing.map((e) => e.version).reduce((a, b) => a > b ? a : b) + 1);
    final item = QuestionBankItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourceDraftId: draft.id ?? '',
      version: version,
      questionText: draft.questionText,
      options: draft.options
          .map((o) => Option(text: o.text, isCorrect: o.isCorrect))
          .toList(),
      topics: List.from(draft.topics),
      difficulty: draft.difficulty,
      previousVersionId: existing.isEmpty ? null : existing.last.id,
    );
    _questionBank.add(item);
    if (useFirestore) {
      try {
        FirestoreService().promoteToQuestionBank(firestoreExamId, draft);
      } catch (_) {}
    }
  }

  void editApprovedQuestion(
    String questionId, {
    required String newQuestionText,
  }) {
    final idx = _questionBank.indexWhere((q) => q.id == questionId);
    if (idx < 0) return;
    final prev = _questionBank[idx];
    // mark old as error_do_not_use
    prev.errorDoNotUse = true;
    // create new version
    final newVersion = QuestionBankItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourceDraftId: prev.sourceDraftId,
      version: prev.version + 1,
      questionText: newQuestionText,
      options: prev.options
          .map((o) => Option(text: o.text, isCorrect: o.isCorrect))
          .toList(),
      topics: List.from(prev.topics),
      difficulty: prev.difficulty,
      previousVersionId: prev.id,
    );
    _questionBank.add(newVersion);
  }

  void forceCommitteeDecision(
    String draftId,
    ReviewVote vote, {
    String note = 'Manual committee decision.',
  }) {
    final draftIndex = _drafts.indexWhere((draft) => draft.id == draftId);
    if (draftIndex < 0) return;

    final draft = _drafts[draftIndex];
    draft.status = vote == ReviewVote.keep ? 'approved' : 'rejected';
    draft.reviewedBy = 'committee';
    draft.committeeNote = note;
  }
}
