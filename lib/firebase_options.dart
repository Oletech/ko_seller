import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAMqfXjlnFGXT4pKIiM_bBoq6axKMElVdg',
    appId: '1:853459286281:android:c4f747a6a0fd240bcb3bd8',
    messagingSenderId: '853459286281',
    projectId: 'kariakoo-babb8',
    storageBucket: 'kariakoo-babb8.appspot.com',
    databaseURL: 'https://kariakoo-babb8.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCs1Y4RfP_0bDK_S9S3AW2SpYN9sb0v04M',
    appId: '1:853459286281:ios:9d0d19f7e7d1c2e4cb3bd8',
    messagingSenderId: '853459286281',
    projectId: 'kariakoo-babb8',
    storageBucket: 'kariakoo-babb8.appspot.com',
    databaseURL: 'https://kariakoo-babb8.firebaseio.com',
    iosBundleId: 'tz.co.oletech.kariakoonlineseller',
  );
}
