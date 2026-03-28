/// Compile-time app configuration.
///
/// Override with:
/// `flutter run --dart-define=API_HOST=http://your-host:8000`
class AppConfig {
  const AppConfig._();

  static const apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const apiBaseUrl = '$apiHost/api';
}
