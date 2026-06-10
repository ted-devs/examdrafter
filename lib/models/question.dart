import 'package:cloud_firestore/cloud_firestore.dart';

class Option {
  final String text;
  final bool isCorrect;

  Option({
    required this.text,
    this.isCorrect = false,
  });

  factory Option.fromMap(Map<String, dynamic> map) {
    return Option(
      text: map['text'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isCorrect': isCorrect,
    };
  }
}

class Question {
  final String id;
  final String sourceDraftId;
  final int version;
  final String questionText;
  final List<Option> options;
  final List<String> topics;
  final String difficulty; // 'Easy' | 'Medium' | 'Hard'
  final String courseId;
  final String authorUid;
  final bool errorDoNotUse;
  final String? previousVersionId;
  final String status; // 'draft' | 'submitted' | 'approved' | 'deprecated'
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.sourceDraftId,
    required this.version,
    required this.questionText,
    required this.options,
    required this.topics,
    required this.difficulty,
    required this.courseId,
    required this.authorUid,
    this.errorDoNotUse = false,
    this.previousVersionId,
    required this.status,
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
    final List<Option> parsedOptions = [];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map<String, dynamic>) {
          parsedOptions.add(Option.fromMap(item));
        } else if (item is Map) {
          parsedOptions.add(Option.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawTopics = data['topics'];
    final List<String> parsedTopics = [];
    if (rawTopics is List) {
      for (final item in rawTopics) {
        parsedTopics.add(item.toString());
      }
    }

    return Question(
      id: id,
      sourceDraftId: data['sourceDraftId'] ?? '',
      version: data['version'] ?? 1,
      questionText: data['questionText'] ?? '',
      options: parsedOptions,
      topics: parsedTopics,
      difficulty: data['difficulty'] ?? 'Medium',
      courseId: data['courseId'] ?? '',
      authorUid: data['authorUid'] ?? '',
      errorDoNotUse: data['errorDoNotUse'] ?? false,
      previousVersionId: data['previousVersionId'],
      status: data['status'] ?? 'draft',
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourceDraftId': sourceDraftId,
      'version': version,
      'questionText': questionText,
      'options': options.map((o) => o.toMap()).toList(),
      'topics': topics,
      'difficulty': difficulty,
      'courseId': courseId,
      'authorUid': authorUid,
      'errorDoNotUse': errorDoNotUse,
      if (previousVersionId != null) 'previousVersionId': previousVersionId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Helper to create a new version of this question.
  Question copyWithNewVersion({
    String? newQuestionText,
    List<Option>? newOptions,
    String? newDifficulty,
    List<String>? newTopics,
    String? newStatus,
    bool? newErrorDoNotUse,
    String? newPreviousVersionId,
  }) {
    return Question(
      id: '', // New document gets a new ID in Firestore
      sourceDraftId: sourceDraftId,
      version: version + 1,
      questionText: newQuestionText ?? questionText,
      options: newOptions ?? options.map((o) => Option(text: o.text, isCorrect: o.isCorrect)).toList(),
      topics: newTopics ?? List.from(topics),
      difficulty: newDifficulty ?? difficulty,
      courseId: courseId,
      authorUid: authorUid,
      errorDoNotUse: newErrorDoNotUse ?? errorDoNotUse,
      previousVersionId: newPreviousVersionId ?? id,
      status: newStatus ?? 'draft',
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
