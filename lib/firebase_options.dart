// Firebase web configuration for project net4207-stock-lab-an.
// These are public client identifiers (not secrets); access is controlled by
// the Firestore security rules in firestore.rules.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'This lab build targets Flutter Web. Run with: flutter run -d chrome',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyABBUnxr6JLlJ6atdc_JbXvczJ9uTs6ekU',
    appId: '1:721563753588:web:b7ed7d9e7a07cc4c450521',
    messagingSenderId: '721563753588',
    projectId: 'net4207-stock-lab-an',
    authDomain: 'net4207-stock-lab-an.firebaseapp.com',
    storageBucket: 'net4207-stock-lab-an.firebasestorage.app',
  );
}
