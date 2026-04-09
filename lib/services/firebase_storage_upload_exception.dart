import 'package:firebase_core/firebase_core.dart';

class FirebaseStorageUploadException implements Exception {
  const FirebaseStorageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

FirebaseStorageUploadException mapFirebaseStorageUploadException(
  Object error,
) {
  if (error is FirebaseException) {
    final rawMessage = error.message?.trim() ?? '';
    final normalized = rawMessage.toLowerCase();

    if (rawMessage.contains('"code": 412') ||
        normalized.contains('required service account') ||
        normalized.contains('re-linking your firebase bucket')) {
      return const FirebaseStorageUploadException(
        'Firebase Storage is not configured correctly for this project. Open Firebase Console > Storage and re-link the bucket, then wait a few minutes and try again.',
      );
    }

    switch (error.code) {
      case 'unauthorized':
        return const FirebaseStorageUploadException(
          'This account is not allowed to upload files to Firebase Storage.',
        );
      case 'canceled':
        return const FirebaseStorageUploadException(
          'The file upload was canceled before it completed.',
        );
      case 'retry-limit-exceeded':
        return const FirebaseStorageUploadException(
          'The upload timed out while talking to Firebase Storage. Try again.',
        );
      case 'bucket-not-found':
      case 'project-not-found':
        return const FirebaseStorageUploadException(
          'The Firebase Storage bucket for this project could not be found.',
        );
      default:
        if (rawMessage.isNotEmpty) {
          return FirebaseStorageUploadException(rawMessage);
        }
    }
  }

  return const FirebaseStorageUploadException(
    'Unable to upload the file to Firebase Storage right now.',
  );
}
