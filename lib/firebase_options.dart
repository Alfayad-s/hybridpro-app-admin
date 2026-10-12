// File generated manually from Firebase console configs.
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Hybrid Pro Admin.');
    }
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAATbd2AR9BGopbo5nC2HLv4GWU32cbE8s',
    appId: '1:832888504626:android:cbf310ccf0eae5f405172b',
    messagingSenderId: '832888504626',
    projectId: 'hybrid-pro-31f8c',
    storageBucket: 'hybrid-pro-31f8c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA9rn2j3ir4Vqi_Ae7z6iwPJA1DjhqMFa4',
    appId: '1:832888504626:ios:0c158fe098e463fc05172b',
    messagingSenderId: '832888504626',
    projectId: 'hybrid-pro-31f8c',
    storageBucket: 'hybrid-pro-31f8c.firebasestorage.app',
    iosBundleId: 'in.hybridpro.hybridProAdmin',
  );
}
