import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:examdrafter/models/notification.dart';

void main() {
  group('SystemNotification Model Tests', () {
    test('fromMap parses correct data with targetUid', () {
      final now = Timestamp.now();
      final map = {
        'targetUid': 'user_uid_123',
        'title': 'Test Title',
        'message': 'Test Message Description',
        'type': 'quota_delegated',
        'relatedRequestId': 'request_456',
        'createdAt': now,
      };

      final notification = SystemNotification.fromMap(map, 'notification_id_789');

      expect(notification.id, 'notification_id_789');
      expect(notification.targetUid, 'user_uid_123');
      expect(notification.title, 'Test Title');
      expect(notification.message, 'Test Message Description');
      expect(notification.type, 'quota_delegated');
      expect(notification.relatedRequestId, 'request_456');
      expect(notification.createdAt, now.toDate());
    });

    test('toMap generates correct map structure with targetUid', () {
      final now = DateTime.now();
      final notification = SystemNotification(
        id: 'notification_id_789',
        targetUid: 'user_uid_123',
        title: 'Test Title',
        message: 'Test Message Description',
        type: 'quota_delegated',
        relatedRequestId: 'request_456',
        createdAt: now,
      );

      final map = notification.toMap();

      expect(map['targetUid'], 'user_uid_123');
      expect(map['title'], 'Test Title');
      expect(map['message'], 'Test Message Description');
      expect(map['type'], 'quota_delegated');
      expect(map['relatedRequestId'], 'request_456');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('fromMap parses general type as default and handles string timestamps', () {
      final map = {
        'targetUid': 'user_uid_123',
        'title': 'Test Title',
        'message': 'Test Message Description',
        'createdAt': '2026-06-17T12:00:00Z',
      };

      final notification = SystemNotification.fromMap(map, 'notification_id_789');

      expect(notification.type, 'general');
      expect(notification.relatedRequestId, isNull);
      expect(notification.createdAt, DateTime.parse('2026-06-17T12:00:00Z'));
    });
  });
}
