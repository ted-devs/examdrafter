class QuestionDraft {
  String? id;
  String teacherId;
  String questionText;
  List<Option> options;
  List<String> topics;
  String difficulty; // Easy|Medium|Hard
  String status; // draft|submitted|in_review|approved|rejected
  String? committeeNote;
  String? reviewedBy;
  QuestionDraft({
    this.id,
    required this.teacherId,
    required this.questionText,
    required this.options,
    required this.topics,
    this.difficulty = 'Medium',
    this.status = 'draft',
    this.committeeNote,
    this.reviewedBy,
  });
}

class Option {
  String text;
  bool isCorrect;
  Option({required this.text, this.isCorrect = false});
}

enum ReviewVote { keep, drop, abstain }

class ReviewRecord {
  String voterId;
  ReviewVote vote;
  bool isTieBreaker;

  ReviewRecord({
    required this.voterId,
    required this.vote,
    this.isTieBreaker = false,
  });
}
