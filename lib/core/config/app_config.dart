class AppConfig {
  AppConfig._();

  /// Pass at run time:
  /// `--dart-define=HYBRID_BACKEND_URL=http://localhost:3002`
  /// or production host e.g. `https://api.hybridpro.in`
  static const String backendUrl = String.fromEnvironment(
    'HYBRID_BACKEND_URL',
    defaultValue: 'http://localhost:3002',
  );

  static String get apiBase =>
      backendUrl.endsWith('/') ? '${backendUrl}api' : '$backendUrl/api';
}
