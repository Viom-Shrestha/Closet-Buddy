import 'package:flutter/material.dart';

import '../core/core.dart';
import '../features/auth/auth.dart';
import '../features/home/home.dart';
import '../features/shared/shared.dart';

/// Entry gate that validates auth state before routing to app/home screens.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _services = ServiceRegistry.instance;

  @override
  void initState() {
    super.initState();
    _handleAuthFlow();
  }

  Future<void> _handleAuthFlow() async {
    await Future.delayed(const Duration(seconds: 4));

    final token = await _services.apiClient.token();
    if (!mounted) return;

    if (token == null) {
      _goTo(const LoginScreen());
      return;
    }

    final profile = await _services.profileService.fetchProfile();
    if (!mounted) return;

    if (profile != null) {
      _goTo(const HomeScreen());
      return;
    }

    final refreshed = await _services.apiClient.refresh();
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
  Widget build(BuildContext context) => const LoadingPage();
}
