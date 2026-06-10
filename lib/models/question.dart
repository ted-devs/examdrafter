import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestionDifficulty {
  easy,
  medium,
  hard;

  String toJson() => name;

  static QuestionDifficulty fromJson(String value) {
    return QuestionDifficulty.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => QuestionDifficulty.easy,
    );
  }
}

enum QuestionStatus {
  draft,
  submitted,
  approved,
  deprecated;

  String toJson() => name;

  static QuestionStatus fromJson(String value) {
    return QuestionStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => QuestionStatus.draft,
    );
  }
}

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctOptionIndex;
  final QuestionDifficulty difficulty;
  final List<String> topicIds;
  final String courseId;
  final String authorUid;
  final int version;
  final QuestionStatus status;
  final String? replacedById;
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctOptionIndex,
    required this.difficulty,
    required this.topicIds,
    required this.courseId,
    required this.authorUid,
    required this.version,
    required this.status,
    this.replacedById,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Question.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    final rawOptions = data['options'];
    final List<String> parsedOptions = [];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        parsedOptions.add(item.toString());
      }
    }

    final rawTopicIds = data['topicIds'];
    final List<String> parsedTopicIds = [];
    if (rawTopicIds is List) {
      for (final item in rawTopicIds) {
        parsedTopicIds.add(item.toString());
      }
    }

    return Question(
      id: id,
      text: data['text'] ?? '',
      options: parsedOptions,
      correctOptionIndex: data['correctOptionIndex'] ?? 0,
      difficulty: QuestionDifficulty.fromJson(data['difficulty'] ?? 'easy'),
      topicIds: parsedTopicIds,
      courseId: data['courseId'] ?? '',
      authorUid: data['authorUid'] ?? '',
      version: data['version'] ?? 1,
      status: QuestionStatus.fromJson(data['status'] ?? 'draft'),
      replacedById: data['replacedById'],
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'difficulty': difficulty.toJson(),
      'topicIds': topicIds,
      'courseId': courseId,
      'authorUid': authorUid,
      'version': version,
      'status': status.toJson(),
      if (replacedById != null) 'replacedById': replacedById,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Helper to create a new version of this question.
  Question copyWithNewVersion({
    String? newText,
    List<String>? newOptions,
    int? newCorrectOptionIndex,
    QuestionDifficulty? newDifficulty,
    List<String>? newTopicIds,
    QuestionStatus? newStatus,
    String? newReplacedById,
  }) {
    return Question(
      id: '', // New document will get a new ID from Firestore
      text: newText ?? text,
      options: newOptions ?? List.from(options),
      correctOptionIndex: newCorrectOptionIndex ?? correctOptionIndex,
      difficulty: newDifficulty ?? difficulty,
      topicIds: newTopicIds ?? List.from(topicIds),
      courseId: courseId,
      authorUid: authorUid,
      version: version + 1,
      status: newStatus ?? QuestionStatus.draft,
      replacedById: newReplacedById,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
