import 'dart:async'; // Needed for Completer
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// --- Constants for SharedPreferences Keys ---
// Consider prefixing keys for better organization, e.g., 'prefs_appVersion'
const String appVersionKey = "appVersion";
const String firstRunDateKey = "firstRunDate";
const String databaseStatusKey = "databaseStatus"; // Example: Tracks local DB setup status
const String weeklyAmountKey = "weeklyAmount";   // Example: User preference
const String DailyRankKey = "dailyRankInfo"; // Stores string like "YYYY-MM-DD/rank"
const String weeklyProgressRoutineIdsKey = "weeklyProgressRoutineIds"; // Key for selected routine IDs
const String themeModeKey = "themeMode"; // Key for storing theme preference (light, dark, system)

// Authentication related keys
const String signInMethodKey = "signInMethod"; // Stores the enum name (e.g., "google", "apple")
const String appleEmailKey = "appleEmail";     // Store email associated with Apple Sign In
const String googleEmailKey = "googleEmail";   // Store email associated with Google Sign In
// Removed credentialKey, passwordKey, gmailPasswordKey due to security concerns

// --- Enum for Sign-In Methods ---
// Make sure this matches the usage in FirebaseProvider etc.
enum SignInMethod {
  apple,
  google,
  // email, // Add if you implement SECURE email/pass sign-in (not via SharedPreferences)
  none,
}

/// Provides an interface for interacting with SharedPreferences.
/// Handles initialization and provides methods for common get/set operations.
class SharedPrefsProvider {
  // Use Completer for robust, one-time initialization of SharedPreferences
  Completer<SharedPreferences>? _initCompleter;

  /// Gets the singleton SharedPreferences instance, initializing it if necessary.
  Future<SharedPreferences> get _prefs async {
    if (_initCompleter == null) {
      // Start initialization if not already started
      _initCompleter = Completer<SharedPreferences>();
      try {
        final prefsInstance = await SharedPreferences.getInstance();
        debugPrint("SharedPrefsProvider: SharedPreferences instance obtained.");
        _initCompleter!.complete(prefsInstance);
      } catch (e) {
        debugPrint("SharedPrefsProvider: Error initializing SharedPreferences: $e");
        _initCompleter!.completeError(e); // Complete with error if init fails
        _initCompleter = null; // Allow retry on next access attempt
        rethrow; // Re-throw the error
      }
    }
    // Wait for initialization to complete (or return immediately if already done)
    return _initCompleter!.future;
  }

  /// Performs initial setup checks on app start (e.g., first run, version update).
  /// Stores relevant info like first run date and current app version.
  /// Returns true if this is determined to be the very first run after install.
  Future<bool> checkAndPrepareOnAppStart() async {
    bool isFirstInstallRun = false;
    try {
      final prefs = await _prefs; // Ensures SharedPreferences is initialized
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      // Check for first run ever (after installation)
      if (!prefs.containsKey(firstRunDateKey)) {
        debugPrint("SharedPrefsProvider: First run detected.");
        isFirstInstallRun = true;
        var dateStr = _dateTimeToString(DateTime.now());
        await prefs.setString(firstRunDateKey, dateStr);
        // Set initial default values
        await prefs.setBool(databaseStatusKey, false); // Example: DB needs setup
        await prefs.setInt(weeklyAmountKey, 3); // Example default
      }

      // Check for first run after app update (or install)
      final storedVersion = prefs.getString(appVersionKey);
      if (storedVersion == null || storedVersion != packageInfo.version) {
        debugPrint("SharedPrefsProvider: App version changed (or first run). Stored: $storedVersion, Current: ${packageInfo.version}");
        await prefs.setString(appVersionKey, packageInfo.version);
        // Trigger specific update logic here if needed (e.g., data migration)
      }

      return isFirstInstallRun;

    } catch (e) {
      debugPrint("SharedPrefsProvider: Error during checkAndPrepareOnAppStart: $e");
      // Depending on the error, decide appropriate return value
      return false; // Assume not first run if error occurs during check
    }
  }

  // --- Getters for App Status / Info ---

  Future<String?> getFirstRunDate() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(firstRunDateKey);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error getting first run date: $e");
      return null;
    }
  }

  Future<String?> getAppVersion() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(appVersionKey);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error getting app version: $e");
      return null;
    }
  }

  /// Gets the status of the local database initialization (example usage).
  Future<bool> getDatabaseStatus() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(databaseStatusKey) ?? false; // Default to false if null
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error getting database status: $e");
      return false; // Default to false on error
    }
  }

  /// Sets the status of the local database initialization (example usage).
  Future<void> setDatabaseStatus(bool dbStatus) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(databaseStatusKey, dbStatus);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error setting database status: $e");
    }
  }

  // --- User Preferences ---

  /// Gets the user's preferred weekly workout amount (example). Returns null if not set.
  Future<int?> getWeeklyAmount() async {
    try {
      final prefs = await _prefs;
      // Use getInt which returns null if key doesn't exist
      return prefs.getInt(weeklyAmountKey);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error getting weekly amount: $e");
      return null;
    }
  }

  /// Sets the user's preferred weekly workout amount (example).
  Future<void> setWeeklyAmount(int amt) async {
    try {
      final prefs = await _prefs;
      await prefs.setInt(weeklyAmountKey, amt);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error setting weekly amount: $e");
    }
  }

  /// Gets the list of routine IDs selected for weekly progress calculation.
  /// Returns an empty list if no IDs are stored or on error.
  Future<List<int>> getWeeklyProgressRoutineIds() async {
    try {
      final prefs = await _prefs;
      final idStrings = prefs.getStringList(weeklyProgressRoutineIdsKey);
      if (idStrings == null) return [];

      // Convert list of strings to list of integers, handling potential parsing errors
      return idStrings.map((idStr) => int.tryParse(idStr)).whereType<int>().toList();
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error getting weekly progress routine IDs: $e");
      return []; // Return empty list on error
    }
  }

  /// Sets the list of routine IDs selected for weekly progress calculation.
  Future<void> setWeeklyProgressRoutineIds(List<int> ids) async {
    try {
      final prefs = await _prefs;
      // Convert list of integers to list of strings
      final idStrings = ids.map((id) => id.toString()).toList();
      await prefs.setStringList(weeklyProgressRoutineIdsKey, idStrings);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error setting weekly progress routine IDs: $e");
    }
  }

  // --- Daily Tracking Example ---

  /// Gets the stored rank for the current day. Returns 0 if no rank for today or on error.
  Future<int> getDailyRank() async {
    try {
      final prefs = await _prefs;
      final dailyRankInfo = prefs.getString(DailyRankKey);
      if (dailyRankInfo == null) return 0;

      final parts = dailyRankInfo.split('/');
      if (parts.length != 2) return 0; // Invalid format

      final datePart = parts[0];
      final rankPart = parts[1];

      final storedDate = DateTime.tryParse(datePart)?.toLocal();
      final currentRank = int.tryParse(rankPart);

      if (storedDate == null || currentRank == null) return 0; // Invalid format

      final today = DateTime.now().toLocal();
      // Check if stored date is today (ignoring time)
      if (storedDate.year == today.year &&
          storedDate.month == today.month &&
          storedDate.day == today.day) {
        return currentRank;
      } else {
        // Stored date is not today
        return 0;
      }
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error getting daily rank: $e");
      return 0; // Return 0 on error
    }
  }

  /// Stores the rank info string (e.g., "YYYY-MM-DD/rank").
  Future<void> setDailyRankInfo(String dailyRankInfo) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(DailyRankKey, dailyRankInfo);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error setting daily rank info: $e");
    }
  }


  // --- Authentication Persistence ---

  /// Saves the email associated with the specific sign-in method.
  /// **Avoid storing passwords here.**
  Future<void> saveAuthProviderEmail(SignInMethod method, String email) async {
    if (email.isEmpty) {
      debugPrint("SharedPrefsProvider: Attempted to save empty email. Aborting.");
      return;
    }
    try {
      final prefs = await _prefs;
      String key;
      switch (method) {
        case SignInMethod.apple:
          key = appleEmailKey;
          break;
        case SignInMethod.google:
          key = googleEmailKey;
          break;
        case SignInMethod.none:
          debugPrint("SharedPrefsProvider: Cannot save email for SignInMethod.none.");
          return; // Don't save for 'none'
      }
      await prefs.setString(key, email);
      debugPrint("SharedPrefsProvider: Saved email for method ${method.name}");
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error saving auth provider email for ${method.name}: $e");
    }
  }

  // Convenience methods for specific providers
  Future<void> saveAppleEmail(String email) async {
    await saveAuthProviderEmail(SignInMethod.apple, email);
  }

  Future<void> saveGoogleEmail(String email) async {
    await saveAuthProviderEmail(SignInMethod.google, email);
  }

  // REMOVED insecure password saving methods

  /// Stores the last used sign-in method using its enum name.
  Future<void> setSignInMethod(SignInMethod signInMethod) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(signInMethodKey, signInMethod.name);
      debugPrint("SharedPrefsProvider: Set SignInMethod to ${signInMethod.name}");
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error setting sign-in method: $e");
    }
  }

  /// Retrieves the last used sign-in method. Defaults to [SignInMethod.none].
  Future<SignInMethod> getSignInMethod() async {
    try {
      final prefs = await _prefs;
      final methodName = prefs.getString(signInMethodKey);
      if (methodName == null) return SignInMethod.none;

      // Find the enum value by its stored name
      return SignInMethod.values.byName(methodName);
    } catch (e) {
      // Handle case where stored name doesn't match any enum value (e.g., corrupted data)
      debugPrint("SharedPrefsProvider: Error parsing stored SignInMethod name. Defaulting to none. Error: $e");
      return SignInMethod.none; // Default to none on error
    }
  }

  // --- Theme Preference ---

  Future<String?> getThemeMode() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(themeModeKey); // Defaults to null if not set
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error getting theme mode: $e");
      return null;
    }
  }

  Future<void> setThemeMode(String mode) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(themeModeKey, mode);
      debugPrint("SharedPrefsProvider: Theme mode set to $mode");
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error setting theme mode: $e");
    }
  }

  // --- Generic Getters/Setters (Use carefully) ---

  Future<String?> getString(String key) async {
    try {
      final prefs = await _prefs;
      return prefs.getString(key);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error getting string for key '$key': $e");
      return null;
    }
  }

  Future<void> setString(String key, String value) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error setting string for key '$key': $e");
    }
  }

  // --- Sign Out ---

  /// Clears authentication-related data from SharedPreferences.
  Future<void> signOut() async {
    try {
      final prefs = await _prefs;
      debugPrint("SharedPrefsProvider: Clearing auth keys from SharedPreferences.");
      // Remove keys related to authentication state
      await prefs.remove(signInMethodKey);
      await prefs.remove(appleEmailKey);
      await prefs.remove(googleEmailKey);
      // Remove other auth-specific keys if you add them
    } catch (e) {
      debugPrint("SharedPrefsProvider: Error during sign out cleanup: $e");
    }
  }

  // --- Helper ---
  String _dateTimeToString(DateTime date) {
    // Ensures 2 digits for month and day
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}

/// Global instance of the SharedPrefsProvider.
/// Consider using a dependency injection framework (like Riverpod, Provider, GetIt)
/// for managing such singletons in larger applications.
final sharedPrefsProvider = SharedPrefsProvider();

// Expose the enum directly if needed elsewhere easily
// export 'package:workout_planner/resource/shared_prefs_provider.dart' show SignInMethod;