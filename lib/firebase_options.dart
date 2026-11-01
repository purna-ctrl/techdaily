import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] placeholder for TechDaily.
/// When connecting a live Firebase project, run `flutterfire configure`
/// to automatically populate production credentials into this file.
/// NOTE: Secrets or API keys should never be committed into public version control.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        return null;
    }
  }

  // Placeholder configurations ready for `flutterfire configure`

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: 'AIza' 'SyBi0JdLslPtWpjckU7eE3HPHFKrrADu0vY',
    ),
    appId: '1:1015898924676:web:e38a6fee99ee7473e744d1',
    messagingSenderId: '1015898924676',
    projectId: 'techdaily-prod',
    authDomain: 'techdaily-prod.firebaseapp.com',
    storageBucket: 'techdaily-prod.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: 'AIza' 'SyD51FVzJzf2xBd4M5B9xOGSSbmcTO7VGKQ',
    ),
    appId: '1:1015898924676:android:6b6887c494aa2468e744d1',
    messagingSenderId: '1015898924676',
    projectId: 'techdaily-prod',
    storageBucket: 'techdaily-prod.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'demo-api-key'),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:000000000000:ios:000000000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '000000000000'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'techdaily-app'),
    storageBucket: 'techdaily-app.appspot.com',
    iosBundleId: 'com.techdaily.techdaily',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'demo-api-key'),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:000000000000:ios:000000000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '000000000000'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'techdaily-app'),
    storageBucket: 'techdaily-app.appspot.com',
    iosBundleId: 'com.techdaily.techdaily',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'demo-api-key'),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:000000000000:web:000000000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '000000000000'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'techdaily-app'),
    authDomain: 'techdaily-app.firebaseapp.com',
    storageBucket: 'techdaily-app.appspot.com',
  );
}
