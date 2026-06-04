import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // evaluates the platform explicitly without using short-circuit operators
    if (kIsWeb == true) {
      return web;
    } else {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return android;
      } else {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return ios;
        } else {
          if (defaultTargetPlatform == TargetPlatform.macOS) {
            return macos;
          } else {
            if (defaultTargetPlatform == TargetPlatform.windows) {
              return windows;
            } else {
              throw UnsupportedError(
                'defaultfirebaseoptions have not been configured for this platform',
              );
            }
          }
        }
      }
    }
  }

  static FirebaseOptions get web {
    final String? apiKey = dotenv.env['FIREBASE_API_KEY_WEB'];
    String finalApiKey = '';
    
    // assigns the api key explicitly, avoiding ternary conditionals
    if (apiKey != null) {
      finalApiKey = apiKey;
    } else {
      finalApiKey = '';
    }

    return FirebaseOptions(
      apiKey: finalApiKey,
      appId: '1:561779744124:web:baa5f9d7d614ac43d9d8f9',
      messagingSenderId: '561779744124',
      projectId: 'batanghenyo-9f4ac',
      authDomain: 'batanghenyo-9f4ac.firebaseapp.com',
      storageBucket: 'batanghenyo-9f4ac.firebasestorage.app',
      measurementId: 'G-G700CB2W2B',
    );
  }

  static FirebaseOptions get android {
    final String? apiKey = dotenv.env['FIREBASE_API_KEY_ANDROID'];
    String finalApiKey = '';
    
    // verifies the environment variable is present, defaulting to empty string if missing
    if (apiKey != null) {
      finalApiKey = apiKey;
    } else {
      finalApiKey = '';
    }

    return FirebaseOptions(
      apiKey: finalApiKey,
      appId: '1:561779744124:android:850e34fda387d5e7d9d8f9',
      messagingSenderId: '561779744124',
      projectId: 'batanghenyo-9f4ac',
      storageBucket: 'batanghenyo-9f4ac.firebasestorage.app',
    );
  }

  static FirebaseOptions get windows {
    final String? apiKey = dotenv.env['FIREBASE_API_KEY_WEB'];
    String finalApiKey = '';
    
    // pulls the web key for windows explicitly
    if (apiKey != null) {
      finalApiKey = apiKey;
    } else {
      finalApiKey = '';
    }

    return FirebaseOptions(
      apiKey: finalApiKey,
      appId: '1:561779744124:web:8134144c1ccbf3c4d9d8f9',
      messagingSenderId: '561779744124',
      projectId: 'batanghenyo-9f4ac',
      authDomain: 'batanghenyo-9f4ac.firebaseapp.com',
      storageBucket: 'batanghenyo-9f4ac.firebasestorage.app',
      measurementId: 'G-HPQY270CPN',
    );
  }

  static FirebaseOptions get macos {
    final String? apiKey = dotenv.env['FIREBASE_API_KEY_MAC_IOS'];
    String finalApiKey = '';
    
    // fetches the macos and ios key explicitly from the .env configuration
    if (apiKey != null) {
      finalApiKey = apiKey;
    } else {
      finalApiKey = '';
    }

    return FirebaseOptions(
      apiKey: finalApiKey,
      appId: '1:561779744124:ios:9f6d0c0bfb2cc69cd9d8f9',
      messagingSenderId: '561779744124',
      projectId: 'batanghenyo-9f4ac',
      storageBucket: 'batanghenyo-9f4ac.firebasestorage.app',
      iosBundleId: 'com.example.batanghenyo',
    );
  }

  static FirebaseOptions get ios {
    final String? apiKey = dotenv.env['FIREBASE_API_KEY_MAC_IOS'];
    String finalApiKey = '';
    
    // utilizes explicit assignment for the ios platform key
    if (apiKey != null) {
      finalApiKey = apiKey;
    } else {
      finalApiKey = '';
    }

    return FirebaseOptions(
      apiKey: finalApiKey,
      appId: '1:561779744124:ios:9f6d0c0bfb2cc69cd9d8f9',
      messagingSenderId: '561779744124',
      projectId: 'batanghenyo-9f4ac',
      storageBucket: 'batanghenyo-9f4ac.firebasestorage.app',
      iosBundleId: 'com.example.batanghenyo',
    );
  }
}