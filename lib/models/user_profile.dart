import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final Map<String, String> roles;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
    required this.roles,
  });

  /// Factory constructor to create a UserProfile from Firestore data.
  factory UserProfile.fromMap(Map<String, dynamic> data, String id) {
    // Parse createdAt timestamp safely
    DateTime parsedCreatedAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.parse(rawCreatedAt);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    // Parse roles map safely
    final rawRoles = data['roles'];
    final Map<String, String> parsedRoles = {};
    if (rawRoles is Map) {
      rawRoles.forEach((key, value) {
        parsedRoles[key.toString()] = value.toString();
      });
    }

    return UserProfile(
      uid: id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      createdAt: parsedCreatedAt,
      roles: parsedRoles,
    );
  }

  /// Convert the UserProfile instance to a Map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'roles': roles,
    };
  }

  /// Helper to check if user has a specific global role
  bool hasGlobalRole(String role) => roles['global'] == role;

  /// Helper to check if user has a specific role in a course or department context
  bool hasRoleInContext(String contextId, String role) => roles[contextId] == role;
}
