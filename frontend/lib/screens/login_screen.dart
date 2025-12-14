import 'package:flutter/material.dart';
import 'package:frontend/widgets/primary_buttons.dart';
import '../services/api_service.dart';
import 'home_screen.dart'; 
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final api = ApiService();

  void login() async {
    // Attempt login and get the token (or null on failure)
    final token = await api.login(_username.text, _password.text);

    if (!mounted) return;
    if (token != false) {
      // 1. Success Message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful! Redirecting...')),
      );

      // 2. Navigation Logic
      // pushReplacement removes the current screen (LoginScreen) from the stack
      // so the user cannot navigate back to it using the back button.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } else {
      // Failure Message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please check credentials.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Welcome Back 👋',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Login to manage your closet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),

            // 1. FIX: Connect to _username controller
            TextField(
              controller: _username, 
              decoration: const InputDecoration(labelText: 'Username')
            ), 
            const SizedBox(height: 16),
            
            // 2. FIX: Connect to _password controller
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),

            const SizedBox(height: 30),
            
            // 3. FIX: Connect button to login function
            PrimaryButton(text: 'Login', onPressed: login), 

            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? "),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}