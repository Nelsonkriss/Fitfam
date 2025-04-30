import 'dart:convert'; // Needed for jsonEncode/Decode
import 'dart:async'; // Needed for Future
import 'package:flutter/foundation.dart'; // For kDebugMode, kIsWeb
import 'package:firebase_auth/firebase_auth.dart';
// Used indirectly by some imports/framework
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/services.dart'; // Not directly used in this snippet, keep if needed elsewhere
import 'package:uuid/uuid.dart'; // For generating IDs if needed elsewhere
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// Import your models and other providers
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart'; // Make sure path is correct

// Key constants (assuming defined in shared_prefs_provider.dart or globally)
const String firstRunDateKey = "firstRunDate";

class FirebaseProvider {
  // Firebase service instances
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  // Google Sign-In instance (null on Web)
  final GoogleSignIn? googleSignIn = kIsWeb ? null : GoogleSignIn();

  // Constructor allowing injection for testing
  FirebaseProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestoreInstance,
  })  : firebaseAuth = auth ?? FirebaseAuth.instance,
        firestore = firestoreInstance ?? FirebaseFirestore.instance;

  // --- Static Methods ---
  static String generateId() {
    return const Uuid().v4();
  }

  // --- User Data Management (Firestore) ---

  /// Uploads the user's current list of routines to Firestore.
  Future<void> uploadRoutines(List<Routine> routines) async {
    // (Implementation remains the same as previous correct version)
    debugPrint("FirebaseProvider: Attempting to upload routines...");
    final user = firebaseAuth.currentUser;
    if (user == null) {
      debugPrint("FirebaseProvider: No authenticated user found. Skipping upload.");
      return;
    }
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint("FirebaseProvider: No internet connection. Skipping upload.");
      throw Exception("No internet connection. Cannot upload routines.");
    }
    try {
      final userRef = firestore.collection("users").doc(user.uid);
      final List<String> routinesJsonList = routines.map((routine) {
        try {
          return jsonEncode(routine.toMapForDb());
        } catch (e, s) {
          debugPrint('FirebaseProvider: Error encoding routine "${routine.routineName}" (ID: ${routine.id}): $e\n$s');
          throw Exception('Failed to encode routine: "${routine.routineName}"');
        }
      }).toList();
      final Map<String, dynamic> userData = {
        "email": user.email,
        "routines": routinesJsonList,
        "lastUpdated": FieldValue.serverTimestamp(),
      };
      await userRef.set(userData, SetOptions(merge: true));
      debugPrint("FirebaseProvider: Successfully uploaded ${routines.length} routines for user ${user.uid}.");
    } catch (e, s) {
      debugPrint('FirebaseProvider: Error uploading routines: $e\n$s');
      rethrow;
    }
  }
// Getter to access the current user from FirebaseAuth
  User? get firebaseUser => firebaseAuth.currentUser;

  /// Restores routines from Firestore for the current user.
  Future<List<Routine>> restoreRoutines() async {
    // (Implementation remains the same as previous correct version)
    debugPrint("FirebaseProvider: Attempting to restore routines...");
    final user = firebaseAuth.currentUser;
    if (user == null) {
      debugPrint("FirebaseProvider: No authenticated user found. Cannot restore.");
      return [];
    }
    try {
      final docRef = firestore.collection("users").doc(user.uid);
      final docSnapshot = await docRef.get();
      final data = docSnapshot.data();
      if (!docSnapshot.exists || data == null || data["routines"] == null || data["routines"] is! List) {
        debugPrint("FirebaseProvider: No routine data found for user ${user.uid} or data is invalid.");
        return [];
      }
      final routinesData = data["routines"] as List;
      final List<Routine> restoredRoutines = [];
      for (final routineJson in routinesData) {
        if (routineJson is String) {
          try {
            final routineMap = jsonDecode(routineJson) as Map<String, dynamic>;
            final routine = Routine.fromMap(routineMap);
            restoredRoutines.add(routine);
          } catch (e, s) {
            debugPrint('FirebaseProvider: Error parsing stored routine JSON: $e\n$s\nJSON: $routineJson');
          }
        } else {
          debugPrint('FirebaseProvider: Skipping non-string item in routines list: $routineJson');
        }
      }
      debugPrint("FirebaseProvider: Successfully restored ${restoredRoutines.length} routines.");
      return restoredRoutines;
    } catch (e, s) {
      debugPrint('FirebaseProvider: Error restoring routines: $e\n$s');
      return [];
    }
  }

  /// Checks if a document exists for the current user in the 'users' collection.
  Future<bool> checkUserExists() async {
    // (Implementation remains the same as previous correct version)
    final user = firebaseAuth.currentUser;
    if (user == null) return false;
    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint("FirebaseProvider: Error checking user existence: $e");
      return false;
    }
  }

  // --- Recommended Routines ---

  /// Fetches recommended routines (e.g., from a dedicated Firestore collection).
  Future<List<Routine>> getRecommendedRoutines() async {
    // (Implementation remains the same as previous correct version)
    debugPrint("FirebaseProvider: Fetching recommended routines...");
    try {
      const String collectionName = "recommendedRoutines"; // *** VERIFY NAME ***
      final collectionRef = firestore.collection(collectionName);
      final querySnapshot = await collectionRef.get(const GetOptions(source: Source.serverAndCache));
      if (querySnapshot.docs.isEmpty) {
        debugPrint("FirebaseProvider: No recommended routines found in collection '$collectionName'.");
        return [];
      }
      final List<Routine> routines = [];
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final routine = Routine.fromMap(data);
          routines.add(routine);
        } catch (e, s) {
          debugPrint("FirebaseProvider: Error parsing recommended routine (ID: ${doc.id}): $e\n$s");
        }
      }
      debugPrint("FirebaseProvider: Successfully fetched ${routines.length} recommended routines.");
      return routines;
    } catch (e, s) {
      debugPrint("FirebaseProvider: Error fetching recommended routines collection: $e\n$s");
      return [];
    }
  }

  // --- Daily Data Example ---

  /// Example: Gets a daily count from a specific Firestore document.
  Future<int> getDailyData() async {
    // (Implementation remains the same as previous correct version)
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint("FirebaseProvider: No connection for getDailyData.");
      return -1;
    }
    final dateStr = _dateTimeToString(DateTime.now().toUtc());
    final docRef = firestore.collection("dailyData").doc(dateStr);
    try {
      final doc = await docRef.get();
      if (doc.exists) {
        return doc.data()?["totalCount"] as int? ?? 0;
      } else {
        await docRef.set({"totalCount": 0});
        return 0;
      }
    } catch (e, s) {
      debugPrint("FirebaseProvider: Error getting daily data for $dateStr: $e\n$s");
      return -1;
    }
  }


  // --- Authentication Methods ---

  /// Attempts to sign in silently primarily by checking the current Firebase user state.
  Future<User?> signInSilently() async {
    // (Implementation remains the same as previous correct version)
    debugPrint("FirebaseProvider: Checking for persisted user session...");
    final currentUser = firebaseAuth.currentUser;
    if (currentUser != null) {
      debugPrint("FirebaseProvider: Found persisted user session for ${currentUser.uid}.");
      return currentUser;
    }
    debugPrint("FirebaseProvider: No persisted user session found.");
    return null;
  }

  /// Initiates Sign In with Apple flow.
  Future<User?> signInWithApple() async {
    // (Implementation remains the same as previous correct version)
    debugPrint("FirebaseProvider: Attempting Sign In with Apple...");
    if (!kIsWeb && !await SignInWithApple.isAvailable()) {
      debugPrint('FirebaseProvider: Sign In with Apple not available on this device.');
      throw Exception('Sign In with Apple is not available on this device.');
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [ AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName, ],
      );
      final oauthProvider = OAuthProvider("apple.com");
      final String? idToken = credential.identityToken;
      final String rawNonce = credential.authorizationCode;
      if (idToken == null) { throw Exception("Apple ID Token was null."); }
      final AuthCredential oauthCredential = oauthProvider.credential(
        idToken: idToken,
        rawNonce: kIsWeb ? null : rawNonce,
        accessToken: kIsWeb ? rawNonce : null,
      );
      final authResult = await firebaseAuth.signInWithCredential(oauthCredential);
      debugPrint("FirebaseProvider: Sign In with Apple successful. User: ${authResult.user?.uid}");
      if (authResult.user != null) { await _handleAppleUserUpdate(authResult.user!, credential); }
      return authResult.user;
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint("FirebaseProvider: Sign In with Apple Authorization Exception: Code=${e.code}, Msg=${e.message}");
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint("FirebaseProvider: Sign In with Apple cancelled by user.");
        return null;
      }
      throw Exception("Apple Sign-In Failed: ${e.message}");
    } catch (e, s) {
      debugPrint("FirebaseProvider: Apple sign-in error: $e\n$s");
      throw Exception("An unexpected error occurred during Apple Sign-In.");
    }
  }

  /// Updates Firebase user profile with Apple data and saves sign-in method.
  Future<void> _handleAppleUserUpdate(User user, AuthorizationCredentialAppleID credential) async {
    // (Implementation largely the same, just the fixed call below)
    bool needsUpdate = false;
    String? newDisplayName;
    String? newEmail = user.email ?? credential.email;
    if ((user.displayName == null || user.displayName!.isEmpty) && credential.givenName != null) {
      newDisplayName = "${credential.givenName} ${credential.familyName ?? ''}".trim();
      if (newDisplayName.isNotEmpty) { needsUpdate = true; } else { newDisplayName = null; }
    }
    if ((user.email == null || user.email!.isEmpty) && credential.email != null) {
      newEmail = credential.email;
      debugPrint("FirebaseProvider: Apple provided email (${credential.email}), consider prompting user to verify if Firebase email is null.");
    }
    if (needsUpdate && newDisplayName != null) {
      try {
        await user.updateDisplayName(newDisplayName);
        debugPrint("FirebaseProvider: Updated Firebase display name from Apple.");
      } catch (e) { debugPrint("FirebaseProvider: Failed to update display name: $e"); }
    }
    await sharedPrefsProvider.setSignInMethod(SignInMethod.apple);
    if (newEmail != null) {
      // *** FIXED: Use the correct method name from SharedPrefsProvider ***
      await sharedPrefsProvider.saveAppleEmail(newEmail);
    }
  }

  /// Initiates Google Sign-In flow (handles Web vs Mobile).
  Future<User?> signInWithGoogle() async {
    // (Implementation remains the same as previous correct version)
    debugPrint("FirebaseProvider: Attempting Google Sign-In...");
    try {
      AuthCredential? credential;
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await firebaseAuth.signInWithPopup(googleProvider);
        if (userCredential.user != null) { await _handleGoogleAuthUpdate(userCredential.user!); }
        return userCredential.user;
      } else {
        if (googleSignIn == null) { throw Exception("Google Sign-In not configured correctly."); }
        final googleUser = await googleSignIn?.signIn();
        if (googleUser == null) { debugPrint("FirebaseProvider: Google Sign-In cancelled by user."); return null; }
        final googleAuth = await googleUser.authentication;
        if (googleAuth.accessToken == null && googleAuth.idToken == null) { throw Exception("Google authentication details were null."); }
        credential = GoogleAuthProvider.credential( accessToken: googleAuth.accessToken, idToken: googleAuth.idToken, );
      }
      final authResult = await firebaseAuth.signInWithCredential(credential);
      debugPrint("FirebaseProvider: Google Sign-In successful. User: ${authResult.user?.uid}");
      if (authResult.user != null) { await _handleGoogleAuthUpdate(authResult.user!); }
      return authResult.user;
    } catch (e, s) {
      debugPrint("FirebaseProvider: Google sign-in error: $e\n$s");
      if (e is FirebaseAuthException && e.code == 'popup-closed-by-user') { return null; }
      throw Exception("Google Sign-In failed.");
    }
  }

  /// Updates Firebase user profile with Google data and saves sign-in method.
  Future<void> _handleGoogleAuthUpdate(User user) async {
    // (Implementation largely the same, just the fixed call below)
    bool needsUpdate = false;
    String? newDisplayName = user.displayName;
    if (newDisplayName == null || newDisplayName.isEmpty) {
      if (user.email != null && user.email!.contains('@')) {
        newDisplayName = user.email!.split('@')[0];
        needsUpdate = true;
      }
    }
    if (needsUpdate && newDisplayName != null && newDisplayName.isNotEmpty) {
      try {
        await user.updateDisplayName(newDisplayName);
        debugPrint("FirebaseProvider: Updated Firebase display name from Google/Email.");
      } catch (e) { debugPrint("FirebaseProvider: Failed to update display name: $e"); }
    }
    await sharedPrefsProvider.setSignInMethod(SignInMethod.google);
    if (user.email != null) {
      // *** FIXED: Use the correct method name from SharedPrefsProvider ***
      await sharedPrefsProvider.saveGoogleEmail(user.email!);
    }
  }

  /// Signs out from Firebase and Google/Apple.
  Future<void> signOut() async {
    // (Implementation remains the same as previous correct version)
    debugPrint("FirebaseProvider: Signing out...");
    try {
      await firebaseAuth.signOut();
      if (!kIsWeb && googleSignIn != null) { await googleSignIn?.signOut(); }
      await sharedPrefsProvider.signOut();
      debugPrint("FirebaseProvider: Sign out complete.");
    } catch (e, s) {
      debugPrint("FirebaseProvider: Error during sign out: $e\n$s");
      await sharedPrefsProvider.signOut();
      throw Exception("Sign out failed.");
    }
  }

  // --- Helpers ---
  /// Formats DateTime to 'YYYY-MM-DD' string.
  String _dateTimeToString(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}

// Global instance (consider using a Provider package for better DI)
final firebaseProvider = FirebaseProvider();