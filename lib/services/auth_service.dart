import 'package:firebase_auth/firebase_auth.dart';

abstract class BaseAuthService {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<UserCredential> signInWithEmail(String email, String password);
  Future<UserCredential> signUpWithEmail(String email, String password);
  Future<void> signOut();
}

class AuthService implements BaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream monitoring authentication state changes.
  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Retrieve the current user.
  @override
  User? get currentUser => _auth.currentUser;

  /// Sign in using Email and Password.
  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during login. Please try again.');
    }
  }

  /// Register using Email and Password.
  @override
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during registration. Please try again.');
    }
  }

  /// Sign out the current user.
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out. Please try again.');
    }
  }

  /// Helper to convert Firebase Auth codes into user-friendly messages.
  Exception _handleAuthException(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No account found with this email. Please sign up.';
        break;
      case 'wrong-password':
        message = 'Incorrect password. Please try again.';
        break;
      case 'invalid-email':
        message = 'Please enter a valid email address.';
        break;
      case 'user-disabled':
        message = 'This user account has been disabled.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email address.';
        break;
      case 'weak-password':
        message = 'The password is too weak. Please use at least 6 characters.';
        break;
      case 'operation-not-allowed':
        message = 'Email/Password authentication is not enabled. Please contact support.';
        break;
      case 'invalid-credential':
        message = 'Invalid credentials details provided. Please check and try again.';
        break;
      default:
        message = e.message ?? 'Authentication error occurred.';
    }
    return Exception(message);
  }
}
