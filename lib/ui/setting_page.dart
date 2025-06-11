import 'dart:async'; // For Future
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Import BLoC, Models, and Providers
import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart BLoC
import 'package:workout_planner/bloc/theme_provider.dart'; // Import ThemeProvider
import 'package:workout_planner/resource/firebase_provider.dart'; // Use global instance
import 'package:workout_planner/resource/shared_prefs_provider.dart'; // Use global instance
import 'package:workout_planner/resource/db_provider.dart'; // Use global instance (for db clear maybe)

// Remove local enum if defined globally in shared_prefs
// enum SignInMethod { google, apple }

class SettingPage extends StatefulWidget {
  final VoidCallback? signInCallback;

  const SettingPage({super.key, this.signInCallback});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  // Use GlobalKey for Scaffold if needed for drawers, snackbars etc.
  // final scaffoldKey = GlobalKey<ScaffoldState>();

  // State for weekly amount preference
  int? _selectedWeeklyAmount; // Use nullable int
  Set<int> _selectedRoutineIds = {}; // State variable for selected routine IDs

  // Access global providers (assuming they exist)
  // final FirebaseProvider firebaseProvider = firebaseProvider; // Already global
  // final SharedPrefsProvider sharedPrefsProvider = sharedPrefsProvider; // Already global
  // Access BLoC via context

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
    _loadSelectedRoutines(); // Load selected routines
  }

  Future<void> _loadInitialSettings() async {
    final amount = await sharedPrefsProvider.getWeeklyAmount();
    if (mounted) {
      setState(() {
        // Default to 3 if not set in prefs
        _selectedWeeklyAmount = amount ?? 3;
      });
    }
  }

  Future<void> _loadSelectedRoutines() async {
    final selectedIds = await sharedPrefsProvider.getWeeklyProgressRoutineIds(); // Need to implement this method
    if (mounted) {
      setState(() {
        _selectedRoutineIds = selectedIds.toSet(); // Convert list to set
      });
    }
  }

  Future<void> _saveSelectedRoutines() async {
    await sharedPrefsProvider.setWeeklyProgressRoutineIds(_selectedRoutineIds.toList()); // Need to implement this method
  }

  // Helper to show messages consistently
  void _showMsgDialog(String title, {String? content}) {
    // Ensure context is valid before showing dialog
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Helper to show SnackBars
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove previous snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }


  // --- Action Handlers ---

  Future<void> _handleRestore(RoutinesBloc bloc) async {
    if (!await _checkConnection()) return;

    try {
      // Check if user is signed in (needed for restore)
      if (firebaseProvider.currentUser == null) {
        _showMsgDialog("Not Signed In", content: "You must be signed in to restore data.");
        return;
      }

      // Check if data exists before attempting restore (optional but good UX)
      final userExists = await firebaseProvider.checkUserExists();
      if (!userExists) {
        _showMsgDialog("Restore Failed", content: "No backup data found for your account.");
        return;
      }

      _showSnackBar("Restoring data from cloud..."); // Show progress indicator?
      final List<Routine> restoredRoutines = await firebaseProvider.restoreRoutines();

      if (restoredRoutines.isNotEmpty) {
        // Replace local DB data with restored data
        await dbProvider.deleteAllRoutines(); // Clear local first
        await dbProvider.addAllRoutines(restoredRoutines); // Add restored

        // Refresh the BLoC stream by fetching from the updated DB
        await bloc.fetchAllRoutines();
        _showMsgDialog("Restore Successful", content: "${restoredRoutines.length} routines restored.");
      } else {
        _showMsgDialog("Restore Info", content: "No routines found in your cloud backup.");
      }
    } catch (e) {
      debugPrint("Restore error: $e");
      _showMsgDialog("Restore Failed", content: "An error occurred: ${e.toString()}");
    }
  }

  Future<void> _handleBackup(RoutinesBloc bloc) async {
    // Check sign-in status
    if (firebaseProvider.currentUser == null) {
      _showSnackBar('Please sign in to back up your data.');
      return;
    }
    if (!await _checkConnection()) return;

    try {
      // Get the current list directly from the BLoC's value getter
      final List<Routine> currentRoutines = bloc.currentRoutinesList;

      if (currentRoutines.isEmpty) {
        _showSnackBar('No routines to back up.');
        return;
      }

      _showSnackBar('Backing up data...'); // Show progress indicator?
      await firebaseProvider.uploadRoutines(currentRoutines);
      _showMsgDialog('Backup Successful', content: 'Your routines have been backed up to the cloud.');

    } catch (e) {
      debugPrint("Backup error: $e");
      _showMsgDialog("Backup Failed", content: "An error occurred: ${e.toString()}");
    }
  }

  Future<bool> _checkConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showSnackBar('No Internet Connection');
      return false;
    }
    return true;
  }


  Future<void> _signInAndPotentiallyRestore(SignInMethod signInMethod, RoutinesBloc bloc) async {
    User? user;
    _showSnackBar("Signing in..."); // Indicate progress
    try {
      // Use the methods directly from the global firebaseProvider instance
      if (signInMethod == SignInMethod.apple) {
        user = await firebaseProvider.signInWithApple();
      } else if (signInMethod == SignInMethod.google) {
        user = await firebaseProvider.signInWithGoogle();
      }

      if (user != null) {
        _showSnackBar("Sign in successful!");
        widget.signInCallback?.call(); // Notify parent if needed

        // Check if user existed *before* sign-in potentially created them
        // Or check if they have existing data to restore
        // We can check if they have routines stored in Firebase
        final userExistsWithData = await firebaseProvider.checkUserExists(); // Re-check after sign-in completes profile creation
        if (userExistsWithData) {
          final routinesInCloud = await firebaseProvider.restoreRoutines(); // Check if routines exist
          if (routinesInCloud.isNotEmpty) {
            _showRestoreConfirmationDialog(bloc); // Show restore confirmation
          } else {
            debugPrint("User exists but no routines found in cloud backup.");
          }
        } else {
          debugPrint("New user signed in or no existing data found.");
        }
      } else {
        // Sign in was cancelled or failed without throwing an exception we caught
        _showSnackBar("Sign in cancelled or failed.");
      }
    } catch (e) {
      debugPrint("Sign in process error: $e");
      _showMsgDialog("Sign-in Failed", content: e.toString());
    }
  }


  // Removed duplicate _signInWithApple and _signInWithGoogle as they exist in firebaseProvider

  void _showRestoreConfirmationDialog(RoutinesBloc bloc) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Restore Data?'),
        content: const Text('Cloud backup found for this account. Would you like to restore it now? This will replace your current local routines.'),
        actions: [
          TextButton(
            child: const Text('Later'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton( // Make restore more prominent
            child: const Text('Restore Now'),
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              await _handleRestore(bloc); // Call restore logic
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    // Optionally confirm sign out
    if (!mounted) return;
    bool confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Sign Out?"),
          content: const Text("Are you sure you want to sign out?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sign Out", style: TextStyle(color: Colors.red))),
          ],
        )
    ) ?? false; // Default to false if dialog dismissed

    if (confirm) {
      try {
        await firebaseProvider.signOut(); // Call provider method
        _showSnackBar("Signed out successfully.");
        widget.signInCallback?.call(); // Notify parent
      } catch (e) {
        _showMsgDialog("Sign Out Failed", content: e.toString());
      }
    }
  }

  void _showSignInModalSheet(RoutinesBloc bloc) {
    if (!mounted) return;
    showCupertinoModalPopup<SignInMethod?>(
      context: context,
      builder: (_) => CupertinoActionSheet( // Use ActionSheet for better iOS look
        // title: const Text("Sign In Options"), // Optional title
        // message: const Text("Choose a sign-in method"), // Optional message
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.google, color: Colors.redAccent.shade700),
                  const SizedBox(width: 15),
                  const Text('Sign in with Google'),
                ],
              ),
              onPressed: () => Navigator.pop(context, SignInMethod.google),
            ),
            // Only show Apple Sign In if available (usually non-web)
            if (!kIsWeb)
              CupertinoActionSheetAction(
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FontAwesomeIcons.apple, color: Colors.black),
                      SizedBox(width: 15),
                      Text('Sign in with Apple'),
                    ]),
                onPressed: () => Navigator.pop(context, SignInMethod.apple),
              ),
          ],
          cancelButton: CupertinoActionSheetAction( // Add cancel button
            isDefaultAction: true,
            onPressed: () { Navigator.pop(context); },
            child: const Text('Cancel'),
          )
      ),
    ).then((method) {
      // Handle the selected method
      if (method != null) {
        _signInAndPotentiallyRestore(method, bloc);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Access the BLoC instance provided by a Provider higher up
    final routinesBlocInstance = context.watch<RoutinesBloc>();

    return Scaffold(
      // key: scaffoldKey, // Only needed if interacting with Scaffold directly
      // Removed outer Material widget as Scaffold provides it
      // Consider adding an AppBar
      appBar: AppBar(
        title: const Text("Settings & Sync"),
        elevation: 1,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Get the current user from the stream snapshot
          final firebaseUser = snapshot.data;
          // *** Removed: firebaseProvider.firebaseUser = firebaseUser; ***

          return ListView(
            children: [
              // --- Sync Section ---
              _buildSectionHeader(context, "Cloud Sync"),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text("Back up Routines"),
                subtitle: const Text("Save your current routines to the cloud"),
                enabled: firebaseUser != null, // Disable if not signed in
                onTap: firebaseUser != null ? () => _handleBackup(routinesBlocInstance) : null,
              ),
              _buildDivider(),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text("Restore Routines"),
                subtitle: const Text("Replace local routines with cloud backup"),
                enabled: firebaseUser != null, // Disable if not signed in
                onTap: firebaseUser != null ? () => _handleRestore(routinesBlocInstance) : null,
              ),

              // --- Account Section ---
              _buildSectionHeader(context, "Account"),
              ListTile(
                leading: Icon(firebaseUser != null ? Icons.logout : Icons.login),
                title: Text(firebaseUser == null ? 'Sign In' : 'Sign Out'),
                subtitle: firebaseUser != null
                    ? Text(firebaseUser.displayName ?? firebaseUser.email ?? 'Signed In')
                    : const Text('Back up & restore across devices'),
                onTap: () {
                  if (firebaseUser == null) {
                    _showSignInModalSheet(routinesBlocInstance);
                  } else {
                    _handleSignOut();
                  }
                },
              ),

              // --- Sharing Section ---
              _buildSectionHeader(context, "Share & Info"),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text("Share App"),
                onTap: () async {
                  // Consider providing more context or a specific App Store link
                  try {
                    final packageInfo = await PackageInfo.fromPlatform();
                    // Example share text
                    final String shareText = 'Check out this Workout Planner app: ${packageInfo.appName}!';
                    // Example link (replace with your actual app store links)
                    // final String appLink = Platform.isAndroid
                    //    ? "https://play.google.com/store/apps/details?id=${packageInfo.packageName}"
                    //    : "https://apps.apple.com/app/id<YOUR_APP_ID>"; // Replace <YOUR_APP_ID>
                    await Share.share(shareText); // Share text only for simplicity
                  } catch(e) {
                    _showSnackBar("Could not get app info to share.");
                  }

                },
              ),
              _buildDivider(),
              // AboutListTile provides standard app info display
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  // Show placeholder or hide while loading
                  if (!snapshot.hasData) return const ListTile(leading: Icon(Icons.info_outline), title: Text("About App"));

                  final packageInfo = snapshot.data!;
                  return AboutListTile(
                    applicationIcon: Padding( // Add padding to icon
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/app_icon.png', // Verify asset path
                        width: 40, // Constrain size
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                    applicationName: packageInfo.appName,
                    applicationVersion: 'Version ${packageInfo.version}',
                    applicationLegalese: '© ${DateTime.now().year} Workout Planner', // Update if needed
                    aboutBoxChildren: [
                      // Link Buttons within the About Box
                      _buildAboutLinkButton(
                        icon: FontAwesomeIcons.github,
                        text: "Source Code (GitHub)",
                        url: "https://github.com/Nelsonkriss/Fitfam", // Verify URL
                      ),
                      _buildAboutLinkButton(
                        icon: FontAwesomeIcons.solidUser, // Example different icon
                        text: "Developer (Nelsonkriss)",
                        url: "https://github.com/Nelsonkriss", // Verify URL
                      ),
                    ],
                    icon: const Icon(Icons.info_outline),
                  );
                },
              ),
              _buildDivider(),

              // --- Settings Section (Example: Weekly Amount) ---
              _buildSectionHeader(context, "Preferences"),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text("Default Weekly Workout Target", style: Theme.of(context).textTheme.titleSmall),
              ),
              if (_selectedWeeklyAmount != null) // Only show if loaded
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButton<int>(
                    value: _selectedWeeklyAmount,
                    isExpanded: true, // Take full width
                    items: List.generate(7, (index) => index + 1) // Generate 1 to 7
                        .map((amount) => DropdownMenuItem<int>(
                      value: amount,
                      child: Text('$amount day${amount > 1 ? 's' : ''} per week'),
                    ))
                        .toList(),
                    onChanged: (newValue) async {
                      if (newValue != null) {
                        await sharedPrefsProvider.setWeeklyAmount(newValue);
                        setState(() {
                          _selectedWeeklyAmount = newValue;
                        });
                        _showSnackBar("Weekly target updated to $newValue days.");
                      }
                    },
                  ),
                )
              else // Show loading indicator while preference loads
                const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                ),
              _buildDivider(),

              // --- Theme Settings Section ---
              _buildSectionHeader(context, "Appearance"),
              Consumer<ThemeProvider>( // Use Consumer to listen to ThemeProvider
                builder: (context, themeProvider, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text("App Theme", style: Theme.of(context).textTheme.titleSmall),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('System Default'),
                        value: ThemeMode.system,
                        groupValue: themeProvider.themeMode,
                        onChanged: (ThemeMode? value) {
                          if (value != null) themeProvider.setThemeMode(value);
                        },
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Light Mode'),
                        value: ThemeMode.light,
                        groupValue: themeProvider.themeMode,
                        onChanged: (ThemeMode? value) {
                          if (value != null) themeProvider.setThemeMode(value);
                        },
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Dark Mode'),
                        value: ThemeMode.dark,
                        groupValue: themeProvider.themeMode,
                        onChanged: (ThemeMode? value) {
                          if (value != null) themeProvider.setThemeMode(value);
                        },
                      ),
                    ],
                  );
                },
              ),
              // --- End Theme Settings Section ---

              // --- Weekly Progress Routines Section ---
              _buildSectionHeader(context, "Weekly Progress Routines"),
              StreamBuilder<List<Routine>>(
                stream: routinesBlocInstance.allRoutinesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading routines: ${snapshot.error}'));
                  }
                  final routines = snapshot.data ?? [];

                  if (routines.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No routines available."),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true, // Important for nested ListViews
                    physics: const NeverScrollableScrollPhysics(), // Disable scrolling for this inner ListView
                    itemCount: routines.length,
                    itemBuilder: (context, index) {
                      final routine = routines[index];
                      // Ensure routine.id is not null before using it as a key
                      if (routine.id == null) return const SizedBox.shrink();

                      final isSelected = _selectedRoutineIds.contains(routine.id);

                      return CheckboxListTile(
                        title: Text(routine.routineName),
                        value: isSelected,
                        onChanged: (bool? newValue) {
                          if (newValue == null) return;
                          setState(() {
                            if (newValue) {
                              _selectedRoutineIds.add(routine.id!);
                            } else {
                              _selectedRoutineIds.remove(routine.id!);
                            }
                          });
                          _saveSelectedRoutines(); // Call a new method to save
                        },
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper for section headers
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary, // Use theme color
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // Helper for consistent dividers
  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 72), // Indent divider from leading icon
      child: Divider(height: 1, thickness: 0.5),
    );
  }

  // Helper for buttons in AboutListTile
  Widget _buildAboutLinkButton({required IconData icon, required String text, required String url}) {
    return TextButton(
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
      child: Row(
        children: [
          FaIcon(icon, size: 18), // Use FaIcon
          const SizedBox(width: 16),
          Text(text),
        ],
      ),
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Could not open link');
        }
      },
    );
  }

}