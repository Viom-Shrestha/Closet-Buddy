import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_client.dart';
import 'services/profile_service.dart';
import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClosetBuddyApp());
}

class ClosetBuddyApp extends StatelessWidget {
  const ClosetBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(), // 👈 Entry point
    );
  }
}

///
/// AuthGate = Loading + Auth Validation
///
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final ApiClient apiClient = ApiClient();
  final ProfileService profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _handleAuthFlow();
  }

  Future<void> _handleAuthFlow() async {
    // Optional splash delay
    await Future.delayed(const Duration(seconds: 4));

    // Check access token
    final token = await apiClient.token();

    if (!mounted) return;

    if (token == null) {
      _goTo(const LoginScreen());
      return;
    }

    // Validate token by fetching profile
    final profile = await profileService.fetchProfile();

    if (!mounted) return;

    if (profile != null) {
      _goTo(const HomeScreen());
      return;
    }

    // Try refresh
    final refreshed = await apiClient.refresh();

    if (!mounted) return;

    if (refreshed) {
      _goTo(const HomeScreen());
    } else {
      _goTo(const LoginScreen());
    }
  }

  void _goTo(Widget page) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingPage();
  }
}

