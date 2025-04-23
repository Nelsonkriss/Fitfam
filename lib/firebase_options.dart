// Auto-generated file - run `flutterfire configure` to update
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgEN0MvuLo1NfnjoKZoBKVbqWJ77_SZ3k',
    appId: '1:196509667512:android:d5c7845d5b6f7d2faba44d',
    messagingSenderId: '196509667512',
    projectId: 'workoutplanner-e6b43',
    storageBucket: 'workoutplanner-e6b43.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCgEN0MvuLo1NfnjoKZoBKVbqWJ77_SZ3k',
    appId: '1:196509667512:ios:d5c7845d5b6f7d2faba44d',
    messagingSenderId: '196509667512',
    projectId: 'workoutplanner-e6b43',
    storageBucket: 'workoutplanner-e6b43.appspot.com',
    iosBundleId: 'com.example.dumbbellNew',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCgEN0MvuLo1NfnjoKZoBKVbqWJ77_SZ3k',
    appId: '1:196509667512:ios:d5c7845d5b6f7d2faba44d',
    messagingSenderId: '196509667512',
    projectId: 'workoutplanner-e6b43',
    storageBucket: 'workoutplanner-e6b43.appspot.com',
    iosBundleId: 'com.example.dumbbellNew',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCgEN0MvuLo1NfnjoKZoBKVbqWJ77_SZ3k',
    appId: '1:196509667512:web:d5c7845d5b6f7d2faba44d',
    messagingSenderId: '196509667512',
    projectId: 'workoutplanner-e6b43',
    storageBucket: 'workoutplanner-e6b43.appspot.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCgEN0MvuLo1NfnjoKZoBKVbqWJ77_SZ3k',
    appId: '1:196509667512:web:d5c7845d5b6f7d2faba44d',
    messagingSenderId: '196509667512',
    projectId: 'workoutplanner-e6b43',
    authDomain: 'workoutplanner-e6b43.firebaseapp.com',
    storageBucket: 'workoutplanner-e6b43.appspot.com',
  );
}