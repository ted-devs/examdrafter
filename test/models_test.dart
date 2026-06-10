import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:examdrafter/models/user_profile.dart';
import 'package:examdrafter/models/taxonomy.dart';
import 'package:examdrafter/models/question.dart';
import 'package:examdrafter/models/exam_request.dart';
import 'package:examdrafter/models/exam_curation.dart';

// Mock class to handle native Firebase Core channel bindings if needed in tests
class TestBindings {
  static void setup() {
    TestWidgetsFlutterBinding.ensureInitialized();
  }
}

void main() {
  TestBindings.setup();

  group('UserProfile Model Tests', () {
    test('fromMap parses correct data', () {
      final now = Timestamp.now();
      final map = {
        'email': 'teacher@school.edu',
        'displayName': 'Teacher Jane',
        'createdAt': now,
        'roles': {
          'global': 'user',
          'course_cs101': 'teacher',
        }
      };

      final profile = UserProfile.fromMap(map, 'user_uid_123');

      expect(profile.uid, 'user_uid_123');
      expect(profile.email, 'teacher@school.edu');
      expect(profile.displayName, 'Teacher Jane');
      expect(profile.createdAt, now.toDate());
      expect(profile.roles['global'], 'user');
      expect(profile.roles['course_cs101'], 'teacher');
      expect(profile.hasGlobalRole('admin'), false);
      expect(profile.hasRoleInContext('course_cs101', 'teacher'), true);
    });

    test('toMap generates correct data structure', () {
      final now = DateTime.now();
      final profile = UserProfile(
        uid: 'user_uid_123',
        email: 'teacher@school.edu',
        displayName: 'Teacher Jane',
        createdAt: now,
        roles: {
          'global': 'user',
          'course_cs101': 'teacher',
        },
      );

      final map = profile.toMap();

      expect(map['email'], 'teacher@school.edu');
      expect(map['displayName'], 'Teacher Jane');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(map['roles']['global'], 'user');
    });
  });

  group('Taxonomy Models Tests', () {
    test('Department serialization', () {
      final now = Timestamp.now();
      final data = {
        'name': 'Computer Science',
        'code': 'CS',
        'createdAt': now,
      };

      final dept = Department.fromMap(data, 'cs_dept');
      expect(dept.id, 'cs_dept');
      expect(dept.name, 'Computer Science');
      expect(dept.code, 'CS');

      final map = dept.toMap();
      expect(map['name'], 'Computer Science');
      expect(map['code'], 'CS');
    });

    test('Course serialization', () {
      final now = Timestamp.now();
      final data = {
        'departmentId': 'cs_dept',
        'name': 'Introduction to OOP',
        'code': 'CS102',
        'createdAt': now,
      };

      final course = Course.fromMap(data, 'cs_102');
      expect(course.id, 'cs_102');
      expect(course.departmentId, 'cs_dept');
      expect(course.code, 'CS102');

      final map = course.toMap();
      expect(map['departmentId'], 'cs_dept');
      expect(map['code'], 'CS102');
    });

    test('Topic serialization', () {
      final now = Timestamp.now();
      final data = {
        'name': 'Recursion',
        'courseIds': ['cs_101', 'cs_102'],
        'createdAt': now,
      };

      final topic = Topic.fromMap(data, 'rec_topic');
      expect(topic.id, 'rec_topic');
      expect(topic.name, 'Recursion');
      expect(topic.courseIds, contains('cs_101'));

      final map = topic.toMap();
      expect(map['name'], 'Recursion');
      expect(map['courseIds'], isA<List>());
      expect(map['courseIds'], contains('cs_102'));
    });
  });

  group('Question Model Tests', () {
    test('fromMap and toMap logic works', () {
      final now = Timestamp.now();
      final data = {
        'text': 'What is recursion?',
        'options': ['Looping', 'Function calling itself', 'Data structure', 'Sorting'],
        'correctOptionIndex': 1,
        'difficulty': 'medium',
        'topicIds': ['topic_1', 'topic_2'],
        'courseId': 'cs_101',
        'authorUid': 'teacher_abc',
        'version': 1,
        'status': 'submitted',
        'createdAt': now,
        'updatedAt': now,
      };

      final q = Question.fromMap(data, 'q_123');
      expect(q.id, 'q_123');
      expect(q.difficulty, QuestionDifficulty.medium);
      expect(q.status, QuestionStatus.submitted);
      expect(q.options[1], 'Function calling itself');

      final map = q.toMap();
      expect(map['difficulty'], 'medium');
      expect(map['status'], 'submitted');
      expect(map['correctOptionIndex'], 1);
    });

    test('copyWithNewVersion increments version and retains author', () {
      final now = DateTime.now();
      final orig = Question(
        id: 'q_orig',
        text: 'Original Text',
        options: ['A', 'B'],
        correctOptionIndex: 0,
        difficulty: QuestionDifficulty.easy,
        topicIds: ['topic_1'],
        courseId: 'cs_101',
        authorUid: 'teacher_abc',
        version: 1,
        status: QuestionStatus.approved,
        createdAt: now,
        updatedAt: now,
      );

      final next = orig.copyWithNewVersion(
        newText: 'Updated Text',
        newStatus: QuestionStatus.draft,
        newReplacedById: 'q_orig',
      );

      expect(next.id, ''); // ID is reset to represent a new document
      expect(next.text, 'Updated Text');
      expect(next.version, 2);
      expect(next.status, QuestionStatus.draft);
      expect(next.authorUid, 'teacher_abc');
      expect(next.replacedById, 'q_orig');
    });
  });

  group('ExamRequest Model Tests', () {
    test('serialization flow', () {
      final now = Timestamp.now();
      final data = {
        'section': 'Section A',
        'departmentId': 'dept_cs',
        'courseId': 'cs_101',
        'questionCount': 10,
        'difficultyDistribution': {
          'easy': 5,
          'medium': 3,
          'hard': 2,
        },
        'adminDeadline': now,
        'status': 'commissioned',
        'createdByUid': 'admin_123',
        'createdAt': now,
      };

      final req = ExamRequest.fromMap(data, 'req_123');
      expect(req.id, 'req_123');
      expect(req.status, ExamRequestStatus.commissioned);
      expect(req.difficultyDistribution['easy'], 5);

      final map = req.toMap();
      expect(map['status'], 'commissioned');
      expect(map['difficultyDistribution']['hard'], 2);
    });
  });

  group('ExamCuration Model Tests', () {
    test('serialization flow', () {
      final data = {
        'teacherDelegations': [
          {'teacherUid': 't_alice', 'courseId': 'cs_101', 'questionCount': 5},
          {'teacherUid': 't_bob', 'courseId': 'cs_101', 'questionCount': 5},
        ],
        'votes': {
          'q_1': ['t_alice', 't_bob'],
          'q_2': ['t_alice'],
        },
        'selectedQuestionIds': ['q_1'],
      };

      final cur = ExamCuration.fromMap(data, 'req_123');
      expect(cur.examRequestId, 'req_123');
      expect(cur.teacherDelegations[0].teacherUid, 't_alice');
      expect(cur.votes['q_1'], contains('t_bob'));
      expect(cur.selectedQuestionIds, contains('q_1'));

      final map = cur.toMap();
      expect(map['teacherDelegations'][1]['teacherUid'], 't_bob');
      expect(map['votes']['q_2'], contains('t_alice'));
    });
  });
}
