import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for project `ycprms-ab68e`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDCp2aSZ-zWgvzc00pChx7es2jvMNjlGxg',
    appId: '1:58922100698:web:770791d7864bd5441002e3',
    messagingSenderId: '58922100698',
    projectId: 'ycprms-ab68e',
    authDomain: 'ycprms-ab68e.firebaseapp.com',
    storageBucket: 'ycprms-ab68e.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDCp2aSZ-zWgvzc00pChx7es2jvMNjlGxg',
    appId: '1:58922100698:android:770791d7864bd5441002e3',
    messagingSenderId: '58922100698',
    projectId: 'ycprms-ab68e',
    storageBucket: 'ycprms-ab68e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDCp2aSZ-zWgvzc00pChx7es2jvMNjlGxg',
    appId: '1:58922100698:ios:770791d7864bd5441002e3',
    messagingSenderId: '58922100698',
    projectId: 'ycprms-ab68e',
    storageBucket: 'ycprms-ab68e.firebasestorage.app',
  );
}
