import 'package:flutter/services.dart';

class AppConfig {
  const AppConfig._();

  static const String _defaultModel = 'mimo v2flash';
  static final Map<String, String> _envValues = <String, String>{};
  static bool _envLoaded = false;

  static Future<void> loadEnvFile({String path = '.env'}) async {
    if (_envLoaded) return;
    try {
      final raw = await rootBundle.loadString(path);
      _envValues
        ..clear()
        ..addAll(_parseEnv(raw));
    } catch (_) {
      // .env is optional at runtime; dart-define fallback still works.
    } finally {
      _envLoaded = true;
    }
  }

  static Map<String, String> _parseEnv(String raw) {
    final result = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final delimiterIndex = trimmed.indexOf('=');
      if (delimiterIndex <= 0) continue;

      final key = trimmed.substring(0, delimiterIndex).trim();
      var value = trimmed.substring(delimiterIndex + 1).trim();

      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }

      result[key] = value;
    }
    return result;
  }

  static String _env(String key) {
    final value = _envValues[key];
    return value?.trim() ?? '';
  }

  static String get openRouterApiKey {
    final fromEnvFile = _env('OPENROUTER_API_KEY');
    if (fromEnvFile.isNotEmpty) return fromEnvFile;

    const primary = String.fromEnvironment('OPENROUTER_API_KEY');
    if (primary.isNotEmpty) return primary;

    final fromEnvFileAlt = _env('OPEN_ROUTER_API_KEY');
    if (fromEnvFileAlt.isNotEmpty) return fromEnvFileAlt;

    const altUnderscore = String.fromEnvironment('OPEN_ROUTER_API_KEY');
    if (altUnderscore.isNotEmpty) return altUnderscore;

    final fromEnvFileLegacy = _env('OPENROUTER_KEY');
    if (fromEnvFileLegacy.isNotEmpty) return fromEnvFileLegacy;

    const legacy = String.fromEnvironment('OPENROUTER_KEY');
    return legacy;
  }

  static String get openRouterModel {
    final fromEnvFile = _env('OPENROUTER_MODEL');
    if (fromEnvFile.isNotEmpty) return fromEnvFile;

    const primary = String.fromEnvironment('OPENROUTER_MODEL');
    if (primary.isNotEmpty) return primary;

    final fromEnvFileLegacy = _env('OPEN_ROUTER_MODEL');
    if (fromEnvFileLegacy.isNotEmpty) return fromEnvFileLegacy;

    const legacy = String.fromEnvironment('OPEN_ROUTER_MODEL');
    return legacy.isEmpty ? _defaultModel : legacy;
  }
}
