import 'package:flutter/material.dart';

import 'admin_screen.dart' as admin_screen;

/// Legacy compatibility wrapper.
/// Prefer importing `admin_screen.dart` directly.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const admin_screen.AdminScreen();
  }
}

