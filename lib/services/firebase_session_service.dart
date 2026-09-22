import 'package:firebase_auth/firebase_auth.dart';

class FirebaseSessionException implements Exception {
  const FirebaseSessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseSessionService {
  FirebaseSessionService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  /// Firebase Auth restores its persisted session asynchronously, so
  /// [currentUser] can be null for a moment after startup even when the seller
  /// is signed in. Callers that would otherwise treat that as "signed out"
  /// await this first. The timeout keeps a cold start from hanging if the
  /// plugin never emits.
  Future<User?> waitForSessionRestore({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    try {
      return await _auth.authStateChanges().first.timeout(timeout);
    } catch (_) {
      return _auth.currentUser;
    }
  }

  Future<User?> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    throw const FirebaseSessionException(
      'Your seller session expired. Sign in again to continue.',
    );
  }

  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
  }
}
