// =============================================================================
// FIREBASE OPTIONS
// =============================================================================
//
// Android values below are populated from android/app/google-services.json
// (project: microflow-442f8).
//
// iOS is NOT configured yet — there is no GoogleService-Info.plist in the tree.
// To enable iOS push notifications, add ios/Runner/GoogleService-Info.plist
// and run `flutterfire configure` (or paste the iOS appId/bundleId below).
//
// =============================================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// To regenerate this file, run `flutterfire configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android config sourced from android/app/google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACSwUvBxinL8JrUth7GhWq7k5C0FJfQAw',
    appId: '1:341779080411:android:ca71c3cb5e3cc6ebe458fe',
    messagingSenderId: '341779080411',
    projectId: 'microflow-442f8',
    storageBucket: 'microflow-442f8.firebasestorage.app',
  );

  // iOS is not configured — add ios/Runner/GoogleService-Info.plist and run
  // `flutterfire configure`, then replace the placeholder appId/bundleId.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyACSwUvBxinL8JrUth7GhWq7k5C0FJfQAw',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '341779080411',
    projectId: 'microflow-442f8',
    storageBucket: 'microflow-442f8.firebasestorage.app',
    iosBundleId: 'com.microflow.pro',
  );
}
