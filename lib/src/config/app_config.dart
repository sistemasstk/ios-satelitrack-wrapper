class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: 'https://app.satelitrack.com.co/',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '2025',
  );

  static const String tokenParamName = String.fromEnvironment(
    'TOKEN_PARAM_NAME',
    defaultValue: 'tokenId',
  );

  static const String mediaBaseUrl = String.fromEnvironment(
    'APP_MEDIA_BASE_URL',
    defaultValue: 'https://intranet.satelitrack.com.co/platform/',
  );

  static Uri resolve(String path) {
    return Uri.parse(baseUrl).resolve(path);
  }
}
