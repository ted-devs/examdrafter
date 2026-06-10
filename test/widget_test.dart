// This is a basic Flutter widget test for Exam Drafter login page.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:examdrafter/services/auth_service.dart';
import 'package:examdrafter/screens/login_page.dart';

class FakeAuthService implements BaseAuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('LoginPage loads and displays components', (WidgetTester tester) async {
    // Build the LoginPage directly using FakeAuthService to bypass FirebaseAuth instance.
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(authService: FakeAuthService()),
      ),
    );

    // Verify that our login page elements are shown.
    expect(find.text('Sign in to access your portal'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
