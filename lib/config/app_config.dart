class AppConfig {
  const AppConfig._();

  static const String _defaultModel = 'mimo v2flash';

  static String get openRouterApiKey {
    return const String.fromEnvironment('OPENROUTER_API_KEY');
  }

  static String get openRouterModel {
    final model = const String.fromEnvironment('OPENROUTER_MODEL');
    return model.isEmpty ? _defaultModel : model;
  }
}
