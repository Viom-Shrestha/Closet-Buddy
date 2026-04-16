import 'package:flutter/foundation.dart';

/// Compile-time app configuration.
///
/// Override with:
/// `flutter run --dart-define=API_HOST=http://your-host:8000`
class AppConfig {
  const AppConfig._();

  static const _apiHostFromDefine = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get apiHost {
    if (_apiHostFromDefine.isNotEmpty) {
      return _apiHostFromDefine;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator maps host machine localhost to 10.0.2.2.
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String get apiBaseUrl => '$apiHost/api';
}
