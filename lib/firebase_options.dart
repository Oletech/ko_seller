import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAMqfXjlnFGXT4pKIiM_bBoq6axKMElVdg',
    appId: '1:853459286281:android:29a9caaa76dcd88bcb3bd8',
    messagingSenderId: '853459286281',
    projectId: 'kariakoo-babb8',
    storageBucket: 'kariakoo-babb8.appspot.com',
    databaseURL: 'https://kariakoo-babb8.firebaseio.com',
  );
}
