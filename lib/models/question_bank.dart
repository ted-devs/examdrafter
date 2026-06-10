import 'question_draft.dart';

class QuestionBankItem {
  String id;
  String sourceDraftId;
  int version;
  String questionText;
  List<Option> options;
  List<String> topics;
  String difficulty;
  DateTime createdAt;
  bool errorDoNotUse;
  String? previousVersionId;

  QuestionBankItem({
    required this.id,
    required this.sourceDraftId,
    required this.version,
    required this.questionText,
    required this.options,
    required this.topics,
    required this.difficulty,
    DateTime? createdAt,
    this.errorDoNotUse = false,
    this.previousVersionId,
  }) : createdAt = createdAt ?? DateTime.now();
}
