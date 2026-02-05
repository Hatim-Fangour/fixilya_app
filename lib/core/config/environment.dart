enum Environment { development, staging, production }

class EnvironmentConfig {
  EnvironmentConfig._();

  static Environment _currentEnvironment = Environment.development;

  static void setEnvironment(Environment env) {
    _currentEnvironment = env;
  }

  static Environment get current => _currentEnvironment;

  static bool get isDevelopment =>
      _currentEnvironment == Environment.development;
  static bool get isStaging => _currentEnvironment == Environment.staging;
  static bool get isProduction => _currentEnvironment == Environment.production;

  static String get apiBaseUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        return 'https://dev-api.fixilya.ma';
      case Environment.staging:
        return 'https://staging-api.fixilya.ma';
      case Environment.production:
        return 'https://api.fixilya.ma';
    }
  }

  static String get firebaseProjectId {
    switch (_currentEnvironment) {
      case Environment.development:
        return 'fixilya-dev';
      case Environment.staging:
        return 'fixilya-staging';
      case Environment.production:
        return 'fixilya-prod';
    }
  }

  static bool get enableLogging => !isProduction;
  static bool get enableDebugMode => isDevelopment;
}
