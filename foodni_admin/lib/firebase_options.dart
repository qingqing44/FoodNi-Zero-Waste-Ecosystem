import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA7QtHhi7Q8x5D7Z7XdvcbUJL-NibLWSnQ',
    appId: '1:599901055825:web:a3bb411c313c9397044170',
    messagingSenderId: '599901055825',
    projectId: 'foodni-project',
    authDomain: 'foodni-project.firebaseapp.com',
    storageBucket: 'foodni-project.firebasestorage.app',
    measurementId: 'G-RCYLVBV4L1',
  );
}