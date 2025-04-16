import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';

const String firstRunDateKey = "firstRunDate";

class FirebaseProvider {
  User? firebaseUser;
  GoogleSignInAccount? googleSignInAccount;
  String? firstRunDate;
  bool isFirstRun = false;
  String? dailyRankInfo;
  int? dailyRank;
  int? weeklyAmount;
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  final GoogleSignIn? googleSignIn = kIsWeb ? null : GoogleSignIn(
    scopes: <String>['email'],
  );

  FirebaseProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestoreInstance,
  })  : firebaseAuth = auth ?? FirebaseAuth.instance,
        firestore = firestoreInstance ?? FirebaseFirestore.instance;

  static String generateId() {
    return const Uuid().v4();
  }

  Future<void> uploadRoutines(List<Routine> routines) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception("No internet connection");
      }

      final user = firebaseAuth.currentUser;
      if (user == null) return;

      final userRef = firestore.collection("users").doc(user.uid);
      
      final routinesData = routines.map((routine) {
        try {
          return jsonEncode(routine.toMap());
        } catch (e) {
          print('Error encoding routine ${routine.routineName}: $e');
          throw Exception('Failed to encode routine: ${routine.routineName}');
        }
      }).toList();

      await userRef.set({
        "registerDate": firstRunDate,
        "email": user.email,
        "routines": routinesData,
      }, SetOptions(merge: true));
      
    } catch (e) {
      print('Error uploading routines: $e');
      rethrow;
    }
  }

  Future<int> getDailyData() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return -1;

    final dateStr = _dateTimeToString(DateTime.now().toUtc());
    final docRef = firestore.collection("dailyData").doc(dateStr);

    final doc = await docRef.get();
    if (doc.exists) {
      return doc.data()?["totalCount"] as int? ?? 0;
    } else {
      await docRef.set({"totalCount": 0});
      return 0;
    }
  }

  Future<bool> checkUserExists() async {
    final user = firebaseAuth.currentUser;
    if (user == null) return false;

    final doc = await firestore.collection('users').doc(user.uid).get();
    return doc.exists;
  }

  Future<List<Routine>> restoreRoutines() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) return [];

      final doc = await firestore.collection("users").doc(user.uid).get();
      final data = doc.data();

      if (data == null || data["routines"] == null) return [];

      return (data["routines"] as List)
          .map((json) {
            try {
              return Routine.fromMap(jsonDecode(json));
            } catch (e) {
              if (kDebugMode) print('Error parsing routine: $e');
              return null;
            }
          })
          .whereType<Routine>()
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error restoring routines: $e');
      return [];
    }
  }

  Future<User?> signInSilently() async {
    final signInMethod = await sharedPrefsProvider.getSignInMethod();
    if (signInMethod == SignInMethod.none) return null;

    final email = await sharedPrefsProvider.getString(
      signInMethod == SignInMethod.apple ? emailKey : gmailKey,
    );
    final password = await sharedPrefsProvider.getString(
      signInMethod == SignInMethod.apple ? passwordKey : gmailPasswordKey,
    );

    if (email == null || password == null) return null;

    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      return null;
    }
  }

  Future<User?> signInWithApple() async {
    if (!await SignInWithApple.isAvailable()) {
      print('Apple SignIn not available');
      return null;
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final authResult = await firebaseAuth.signInWithCredential(oauthCredential);
      await _handleAppleUserUpdate(authResult.user!, credential);
      return authResult.user;
    } catch (e) {
      print("Apple sign-in error: $e");
      return null;
    }
  }

  Future<void> _handleAppleUserUpdate(
      User user, AuthorizationCredentialAppleID credential) async {
    if (user.displayName == null && credential.givenName != null) {
      final displayName = 
          "${credential.givenName} ${credential.familyName ?? ''}".trim();
      await user.updateDisplayName(displayName);
    }

    await sharedPrefsProvider.setSignInMethod(SignInMethod.apple);
    await sharedPrefsProvider.saveEmailAndPassword(
      user.email ?? credential.email ?? '',
      '', // Apple doesn't provide a password
    );
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await firebaseAuth.signInWithPopup(googleProvider);
        await _handleGoogleAuthUpdate(userCredential.user!);
        return userCredential.user;
      }
      
      if (googleSignIn == null) return null;
      final googleUser = await googleSignIn?.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final authResult = await firebaseAuth.signInWithCredential(credential);
      await _handleGoogleAuthUpdate(authResult.user!);
      return authResult.user;
    } catch (e) {
      print("Google sign-in error: $e");
      return null;
    }
  }

  Future<void> _handleGoogleAuthUpdate(User user) async {
    if (user.displayName == null && user.email != null) {
      await user.updateDisplayName(user.email!.split('@')[0]);
    }

    await sharedPrefsProvider.setSignInMethod(SignInMethod.google);
    await sharedPrefsProvider.saveGmailAndPassword(
      user.email ?? '',
      '',
    );
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
    if (googleSignIn != null) {
      await googleSignIn?.signOut();
    }
    await sharedPrefsProvider.signOut();
  }

  String _dateTimeToString(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}

final firebaseProvider = FirebaseProvider();
