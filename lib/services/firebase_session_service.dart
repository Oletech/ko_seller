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
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } on FirebaseAuthException catch (error) {
      throw FirebaseSessionException(_messageForAuthError(error));
    } catch (_) {
      throw const FirebaseSessionException(
        'Unable to connect this app to Firebase right now. Try again after a full app restart.',
      );
    }
  }

  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
  }

  String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Firebase Anonymous sign-in is disabled for this project. Enable Anonymous under Authentication > Sign-in method in Firebase Console.';
      case 'network-request-failed':
        return 'Firebase sign-in failed because the device could not reach the network.';
      case 'invalid-api-key':
        return 'Firebase rejected the API key configured for this app.';
      case 'app-not-authorized':
        return 'This app is not authorized to use the current Firebase project configuration.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Unable to create a Firebase session for this seller account.';
    }
  }
}
