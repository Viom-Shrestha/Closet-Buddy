import 'package:flutter/material.dart';

import 'app/app.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.instance.initialize();
  runApp(const ClosetBuddyApp());
}
