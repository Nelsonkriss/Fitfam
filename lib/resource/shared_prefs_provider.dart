import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/resource/firebase_provider.dart';

// Constants
const String AppVersionKey = "appVersion";
const String DailyRankKey = "dailyRank";
const String DatabaseStatusKey = "databaseStatus";
const String WeeklyAmountKey = "weeklyAmount";
const String credentialKey = "credentialKey";
const String emailKey = "emailKey";
const String passwordKey = "passwordKey";
const String gmailKey = "gmailKey";
const String gmailPasswordKey = "gmailPasswordKey";
const String signInMethodKey = "signInMethodKey";
const String FirstRunDateKey = "firstRunDate";

enum SignInMethod {
  apple,
  google,
  none,
}

class SharedPrefsProvider {
  SharedPreferences? _sharedPreferences;

  Future<SharedPreferences> get sharedPreferences async {
    if (_sharedPreferences != null) return _sharedPreferences!;
    _sharedPreferences = await SharedPreferences.getInstance();
    return _sharedPreferences!;
  }

  Future<void> prepareData() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    SharedPreferences prefs = await sharedPreferences;

    // If true, this is the first time the app is run after installation
    if (prefs.getString(FirstRunDateKey) == null) {
      var dateStr = dateTimeToStringConverter(DateTime.now());
      prefs.setString(FirstRunDateKey, dateStr);
      prefs.setBool(DatabaseStatusKey, false);
      prefs.setInt(WeeklyAmountKey, 3);
    }

    // If true, this is the first time the app is run after installation/update
    if (prefs.getString(AppVersionKey) == null ||
        prefs.getString(AppVersionKey) != packageInfo.version) {
      prefs.setString(AppVersionKey, packageInfo.version);
      firebaseProvider.isFirstRun = true;
    } else {
      firebaseProvider.isFirstRun = false;
    }
    firebaseProvider.firstRunDate = prefs.getString(FirstRunDateKey);
    // Additional assignments for dailyRankInfo, dailyRank, and weeklyAmount can be added here.
  }

  /// Return 0 if no workout today.
  Future<int> getDailyRank() async {
    SharedPreferences prefs = await sharedPreferences;
    String? dailyRankInfo = prefs.getString(DailyRankKey);
    if (dailyRankInfo == null ||
        DateTime.now().day -
            DateTime.parse(dailyRankInfo.split('/').first).toLocal().day ==
            1) {
      return 0;
    }
    return int.parse(dailyRankInfo.split('/')[1]);
  }

  Future<void> setWeeklyAmount(int amt) async {
    SharedPreferences prefs = await sharedPreferences;
    prefs.setInt(WeeklyAmountKey, amt);
    firebaseProvider.weeklyAmount = amt;
  }

  Future<void> setDailyRankInfo(String dailyRankInfo) async {
    SharedPreferences prefs = await sharedPreferences;
    prefs.setString(DailyRankKey, dailyRankInfo);
  }

  Future<void> setDatabaseStatus(bool dbStatus) async {
    SharedPreferences prefs = await sharedPreferences;
    prefs.setBool(DatabaseStatusKey, dbStatus);
  }

  Future<bool> getDatabaseStatus() async {
    SharedPreferences prefs = await sharedPreferences;
    return prefs.getBool(DatabaseStatusKey) ?? false;
  }

  Future<void> saveEmailAndPassword(String email, String password) async {
    print("Saving email and password");
    final sharedPrefs = await sharedPreferences;
    sharedPrefs.setString(emailKey, email);
    sharedPrefs.setString(passwordKey, password);
  }

  Future<void> saveGmailAndPassword(String email, String password) async {
    print("Saving email and password");
    final sharedPrefs = await sharedPreferences;
    sharedPrefs.setString(gmailKey, email);
    sharedPrefs.setString(gmailPasswordKey, password);
  }

  Future<void> setSignInMethod(SignInMethod signInMethod) async {
    final sharedPrefs = await sharedPreferences;
    int value;
    switch (signInMethod) {
      case SignInMethod.apple:
        value = 0;
        break;
      case SignInMethod.google:
        value = 1;
        break;
      default:
        throw Exception("Unmatched SignInMethod value");
    }
    sharedPrefs.setInt(signInMethodKey, value);
  }

  /// Get the sign in method last time.
  Future<SignInMethod> getSignInMethod() async {
    final sharedPrefs = await sharedPreferences;
    int? value = sharedPrefs.getInt(signInMethodKey);
    return value == null ? SignInMethod.none : SignInMethod.values[value];
  }

  Future<String?> getString(String key) async {
    final sharedPrefs = await sharedPreferences;
    return sharedPrefs.getString(key);
  }

  Future<void> setString(String key, String value) async {
    final sharedPrefs = await sharedPreferences;
    sharedPrefs.setString(key, value);
  }

  Future<void> signOut() async {
    final prefs = await sharedPreferences;
    prefs.remove(credentialKey);
  }
}

String dateTimeToStringConverter(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
}

final sharedPrefsProvider = SharedPrefsProvider();
