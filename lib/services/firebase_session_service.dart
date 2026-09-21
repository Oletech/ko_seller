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
