import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final AuthService authService = ServiceRegistry.instance.authService;
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  static const String _termsAndConditionsText = '''
Terms and Conditions for Closet Buddy

Last Updated: April 2026

1. Introduction
Welcome to Closet Buddy ("we", "our", "us"). These Terms and Conditions ("Terms") govern your use of the Closet Buddy mobile application and related services (the "Service").
By accessing or using Closet Buddy, you agree to be bound by these Terms. If you do not agree, please do not use the Service.

2. Eligibility
You must be at least 13 years old to use Closet Buddy. By using the Service, you confirm that you meet this requirement.

3. User Accounts
To access certain features, you may be required to create an account.
You agree to:
- Provide accurate and complete information
- Maintain the confidentiality of your login credentials
- Be responsible for all activities under your account
We reserve the right to suspend or terminate accounts that violate these Terms.

4. Description of Service
Closet Buddy is an AI-powered digital wardrobe application that allows users to:
- Upload and manage clothing items
- Organize items in a virtual closet
- Receive outfit recommendations
- Create and save outfits
- Track clothing usage and preferences
We may update, modify, or discontinue features at any time without prior notice.

5. User Content
You retain ownership of all images and content you upload ("User Content").
By uploading content, you grant Closet Buddy a non-exclusive, worldwide, royalty-free license to:
- Store and process your content
- Analyze images for classification and recommendations
- Improve system functionality and user experience
You agree not to upload content that:
- Is illegal, harmful, or offensive
- Violates intellectual property rights
- Contains malicious code or harmful data

6. AI-Based Features Disclaimer
Closet Buddy uses artificial intelligence to classify clothing and generate outfit recommendations.
You acknowledge that:
- AI predictions may not always be accurate
- Recommendations are for informational purposes only
- We do not guarantee correctness or suitability of outfits

7. Privacy
Your use of Closet Buddy is also governed by our Privacy Policy.
We may collect and process:
- Uploaded images
- Clothing metadata (e.g., type, color)
- User interaction and usage data
This information is used to improve the Service and personalize recommendations.

8. Data Storage and Deletion
You may delete your uploaded content at any time.
You may delete your account, which will remove associated data (subject to system limitations).
We are not responsible for data loss due to technical failures.

9. Prohibited Activities
You agree not to:
- Attempt to hack, disrupt, or damage the Service
- Upload malicious files or harmful content
- Use the Service for unlawful purposes
- Reverse engineer or copy the system or its components

10. Intellectual Property
All rights related to the Service, including application design, source code, AI models, and algorithms are owned by Closet Buddy, except for User Content.
You may not copy, modify, distribute, or reproduce any part of the Service without permission.

11. Limitation of Liability
Closet Buddy is provided on an "as is" and "as available" basis.
We are not liable for:
- Errors in AI recommendations
- Loss of data
- Service interruptions
- Any indirect or consequential damages

12. Termination
We may suspend or terminate your account if:
- You violate these Terms
- You misuse the Service
You may terminate your account at any time.

13. Changes to Terms
We may update these Terms from time to time. Continued use of the Service after changes indicates your acceptance of the updated Terms.

14. Governing Law
These Terms shall be governed by the laws of Nepal.

15. Academic Project Notice
Closet Buddy is developed as an academic Final Year Project (FYP). The Service may be experimental, and certain features may not be fully stable or production-ready.

16. Contact Information
For questions or support, please contact:
Email: closetbuddy.app@gmail.com
''';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void register() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please agree to the Terms and Conditions'),
            backgroundColor: AuthTokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final success = await authService.register(
        _username.text,
        _email.text,
        _password.text,
        _confirmPassword.text,
        _first.text,
        _last.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: AuthTokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed. Please try again.'),
            backgroundColor: AuthTokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showTermsAndConditions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuthTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.88;
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Terms and Conditions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AuthTokens.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: AuthTokens.muted),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AuthTokens.line),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    child: SelectableText(
                      _termsAndConditionsText,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AuthTokens.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTokens.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 40),

                    // Logo and branding
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AuthTokens.ink.withValues(alpha: 0.15),
                                blurRadius: 24,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: AppLogo(
                            size: 72,
                            borderRadius: 20,
                            darkBackground: true,
                          ),
                        ),

                        SizedBox(height: 24),

                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AuthTokens.ink,
                            letterSpacing: -0.5,
                          ),
                        ),

                        SizedBox(height: 8),

                        Text(
                          'Join your AI-powered style journey',
                          style: TextStyle(
                            fontSize: 15,
                            color: AuthTokens.muted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 40),

                    // Registration form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Name fields (side by side)
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  label: 'First Name',
                                  controller: _first,
                                  icon: Icons.person_outline,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildField(
                                  label: 'Last Name',
                                  controller: _last,
                                  icon: Icons.person_outline,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20),

                          // Username field
                          _buildField(
                            label: 'Username',
                            controller: _username,
                            icon: Icons.alternate_email,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 20),

                          // Email field
                          _buildField(
                            label: 'Email address',
                            controller: _email,
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@') ||
                                  !value.contains('.')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 20),

                          // Password field
                          _buildField(
                            label: 'Password',
                            controller: _password,
                            icon: Icons.lock_outline,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            onToggleVisibility: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 20),

                          // Confirm Password field
                          _buildField(
                            label: 'Confirm Password',
                            controller: _confirmPassword,
                            icon: Icons.lock_outline,
                            isPassword: true,
                            obscureText: _obscureConfirmPassword,
                            onToggleVisibility: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _password.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 20),

                          // Terms and conditions
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _agreeToTerms,
                                  onChanged: (value) {
                                    setState(() {
                                      _agreeToTerms = value ?? false;
                                    });
                                  },
                                  fillColor:
                                      const WidgetStatePropertyAll<Color>(
                                        AuthTokens.ink,
                                      ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'I agree to the ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AuthTokens.muted,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _showTermsAndConditions,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Terms and Conditions',
                                        style: TextStyle(
                                          color: AuthTokens.ink,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!_agreeToTerms) ...[
                            SizedBox(height: 8),
                            Text(
                              'Please accept the Terms and Conditions to create your account.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AuthTokens.muted,
                              ),
                            ),
                          ],

                          SizedBox(height: 28),

                          // Register button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed:
                                  (_isLoading || !_agreeToTerms) ? null : register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AuthTokens.ink,
                                foregroundColor: AuthTokens.surface,
                                disabledBackgroundColor: AuthTokens.ink
                                    .withValues(alpha: 0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                shadowColor: AuthTokens.transparent,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AuthTokens.surface,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Login redirect
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: AuthTokens.muted,
                            fontSize: 15,
                          ),
                        ),

                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Sign in',
                              style: TextStyle(
                                color: AuthTokens.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AuthTokens.ink,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AuthTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuthTokens.line, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AuthTokens.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(fontSize: 15, color: AuthTokens.ink),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: AuthTokens.mutedSoft),
              prefixIcon: Icon(icon, color: AuthTokens.muted, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AuthTokens.muted,
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              errorStyle: TextStyle(fontSize: 12, height: 0.8),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}
