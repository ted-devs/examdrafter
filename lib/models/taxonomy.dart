import 'package:cloud_firestore/cloud_firestore.dart';

class Department {
  final String id;
  final String name;
  final String code;
  final DateTime createdAt;

  Department({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
  });

  factory Department.fromMap(Map<String, dynamic> data, String id) {
    DateTime parsedCreatedAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.parse(rawCreatedAt);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return Department(
      id: id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Course {
  final String id;
  final String departmentId;
  final String name;
  final String code;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.code,
    required this.createdAt,
  });

  factory Course.fromMap(Map<String, dynamic> data, String id) {
    DateTime parsedCreatedAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.parse(rawCreatedAt);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return Course(
      id: id,
      departmentId: data['departmentId'] ?? '',
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'departmentId': departmentId,
      'name': name,
      'code': code,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Topic {
  final String id;
  final String name;
  final List<String> courseIds;
  final DateTime createdAt;

  Topic({
    required this.id,
    required this.name,
    required this.courseIds,
    required this.createdAt,
  });

  factory Topic.fromMap(Map<String, dynamic> data, String id) {
    DateTime parsedCreatedAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.parse(rawCreatedAt);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    final rawCourseIds = data['courseIds'];
    final List<String> parsedCourseIds = [];
    if (rawCourseIds is List) {
      for (final item in rawCourseIds) {
        parsedCourseIds.add(item.toString());
      }
    }

    return Topic(
      id: id,
      name: data['name'] ?? '',
      courseIds: parsedCourseIds,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'courseIds': courseIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Section {
  final String id;
  final String courseId;
  final String name;
  final DateTime createdAt;

  Section({
    required this.id,
    required this.courseId,
    required this.name,
    required this.createdAt,
  });

  factory Section.fromMap(Map<String, dynamic> data, String id) {
    DateTime parsedCreatedAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.parse(rawCreatedAt);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return Section(
      id: id,
      courseId: data['courseId'] ?? '',
      name: data['name'] ?? '',
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
