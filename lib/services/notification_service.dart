import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sends a notification to a specific user.
  Future<void> sendNotification({
    required String targetUid,
    required String title,
    required String message,
    required String type,
    String? relatedRequestId,
  }) async {
    final docRef = _firestore.collection('notifications').doc();
    final notification = SystemNotification(
      id: docRef.id,
      targetUid: targetUid,
      title: title,
      message: message,
      type: type,
      relatedRequestId: relatedRequestId,
      createdAt: DateTime.now(),
    );
    await docRef.set(notification.toMap());
  }

  /// Sends notifications to all users who have any of the target roles for the specified course.
  Future<void> sendNotificationToCourseRole({
    required String courseId,
    required List<String> targetRoles,
    required String title,
    required String message,
    required String type,
    String? relatedRequestId,
  }) async {
    try {
      final querySnapshot = await _firestore.collection('users').get();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final roles = data['roles'] as Map<String, dynamic>? ?? {};
        final courseRole = roles['course_$courseId'];
        if (courseRole != null && targetRoles.contains(courseRole)) {
          await sendNotification(
            targetUid: doc.id,
            title: title,
            message: message,
            type: type,
            relatedRequestId: relatedRequestId,
          );
        }
      }
    } catch (e) {
      // Ignored or logged in debug mode
    }
  }

  /// Sends notifications to all global admins and super admins.
  Future<void> sendNotificationToAdmins({
    required String title,
    required String message,
    required String type,
    String? relatedRequestId,
  }) async {
    try {
      final querySnapshot = await _firestore.collection('users').get();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final roles = data['roles'] as Map<String, dynamic>? ?? {};
        final globalRole = roles['global'];
        if (globalRole == 'admin' || globalRole == 'super_admin') {
          await sendNotification(
            targetUid: doc.id,
            title: title,
            message: message,
            type: type,
            relatedRequestId: relatedRequestId,
          );
        }
      }
    } catch (e) {
      // Ignored or logged in debug mode
    }
  }

  /// Dismisses (deletes) a notification from Firestore.
  Future<void> dismissNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}
