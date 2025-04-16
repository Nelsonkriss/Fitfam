import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/resource/firebase_provider.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';

enum SignInMethod { google, apple }

class SettingPage extends StatefulWidget {
  final VoidCallback? signInCallback;

  const SettingPage({Key? key, this.signInCallback}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late int selectedRadioValue;
  final FirebaseProvider firebaseProvider = FirebaseProvider();
  final RoutinesBloc routinesBloc = RoutinesBloc();
  final SharedPrefsProvider sharedPrefsProvider = SharedPrefsProvider();

  @override
  void initState() {
    super.initState();
    selectedRadioValue = firebaseProvider.weeklyAmount ?? 3;
  }

  Future<void> handleRestore() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showMsg("No Internet Connection");
      return;
    }

    try {
      final userExists = await firebaseProvider.checkUserExists();
      if (!userExists) {
        showMsg("No Data Found");
        return;
      }

      final success = await routinesBloc.restoreRoutines();
      if (success) {
        showMsg("Restored Successfully");
      } else {
        showMsg("Restore Failed");
      }
    } catch (e) {
      showMsg("Error during restore: ${e.toString()}");
    }
  }

  Future<void> onBackUpTapped() async {
    if (firebaseProvider.firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No User Signed In'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Internet Connection'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await routinesBloc.allRoutines.first.then((routines) async {
        await firebaseProvider.uploadRoutines(routines);
        showMsg('Data uploaded successfully');
      });
    } catch (e) {
      showMsg("Backup failed: ${e.toString()}");
    }
  }

  void showMsg(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(msg),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> signInAndRestore(SignInMethod signInMethod) async {
    try {
      User? firebaseUser;
      if (signInMethod == SignInMethod.apple) {
        firebaseUser = await _signInWithApple();
      } else if (signInMethod == SignInMethod.google) {
        firebaseUser = await _signInWithGoogle();
      }

      if (firebaseUser != null) {
        widget.signInCallback?.call();
        final userExists = await firebaseProvider.checkUserExists();
        if (userExists) showRestoreDialog();
      }
    } catch (e) {
      showMsg("Sign-in failed: ${e.toString()}");
    }
  }

  Future<User?> _signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final authResult = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      return authResult.user;
    } catch (e) {
      print("Apple sign in error: $e");
      return null;
    }
  }

  Future<User?> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final authResult = await FirebaseAuth.instance.signInWithCredential(credential);
      return authResult.user;
    } catch (e) {
      print("Google sign in error: $e");
      return null;
    }
  }

  void showRestoreDialog() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Restore your data?'),
      content: const Text('Looks like you have data on the cloud. Restore to this device?'),
      actions: [
        TextButton(
          child: const Text('No'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: const Text('Yes'),
          onPressed: () async {
            await routinesBloc.restoreRoutines();
            Navigator.pop(context);
          },
        ),
      ],
    ),
  );

  void signOut() {
    FirebaseAuth.instance.signOut();
    GoogleSignIn().signOut();
    sharedPrefsProvider.signOut();
  }

  void showSignInModalSheet() {
    showCupertinoModalPopup<SignInMethod?>(
      context: context,
      builder: (_) => Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Transform.scale(
              scale: 1.2,
              child: SignInButtonBuilder(
                backgroundColor: Colors.blue,
                text: 'Sign in with Google',
                icon: FontAwesomeIcons.google,
                onPressed: () => Navigator.pop(context, SignInMethod.google),
              ),
            ),
            const SizedBox(height: 12),
            Transform.scale(
              scale: 1.2,
              child: SignInButton(
                Buttons.Apple,
                onPressed: () => Navigator.pop(context, SignInMethod.apple),
              ),
            ),
          ],
        ),
      ),
    ).then((method) {
      if (method != null) signInAndRestore(method);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      body: Material(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final firebaseUser = snapshot.data;
            firebaseProvider.firebaseUser = firebaseUser;

            return ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text("Back up my data"),
                  onTap: onBackUpTapped,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Divider(height: 0),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text("Restore my data"),
                  onTap: () {
                    if (firebaseUser == null) {
                      showMsg("You must sign in first");
                      return;
                    }
                    handleRestore();
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Divider(height: 0),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(firebaseUser == null ? 'Sign In' : 'Sign Out'),
                  subtitle: firebaseUser?.displayName != null
                      ? Text(firebaseUser!.displayName!)
                      : null,
                  onTap: () {
                    if (firebaseUser == null) {
                      showSignInModalSheet();
                    } else {
                      signOut();
                    }
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Divider(height: 0),
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text("Share app"),
                  onTap: () async {
                    final packageInfo = await PackageInfo.fromPlatform();
                    Share.share(
                        'Check out ${packageInfo.appName} - ${packageInfo.packageName}');
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Divider(height: 0),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    final packageInfo = snapshot.data!;
                    return AboutListTile(
                      applicationIcon: Container(
                        width: 50,
                        height: 50,
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      applicationVersion: 'v${packageInfo.version}',
                      applicationLegalese: '© ${DateTime.now().year} Workout Planner',
                      aboutBoxChildren: [
                        TextButton(
                          child: const Row(
                            children: [
                              Icon(FontAwesomeIcons.addressCard),
                              SizedBox(width: 12),
                              Text("Developer"),
                            ],
                          ),
                          onPressed: () => launchUrl(Uri.parse("https://github.com/Nelsonkriss")),
                        ),
                        TextButton(
                          child: const Row(
                            children: [
                              Icon(FontAwesomeIcons.github),
                              SizedBox(width: 12),
                              Text("Source Code"),
                            ],
                          ),
                          onPressed: () => launchUrl(
                              Uri.parse("https://github.com/Nelsonkriss/Fitfam")),
                        ),
                      ],
                      icon: const Icon(Icons.info),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}