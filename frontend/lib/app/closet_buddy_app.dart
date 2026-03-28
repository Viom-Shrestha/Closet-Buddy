import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'auth_gate.dart';

class ClosetBuddyApp extends StatelessWidget {
  const ClosetBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (context, mode, child) => MaterialApp(
        key: ValueKey(mode),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: const AuthGate(),
      ),
    );
  }
}
