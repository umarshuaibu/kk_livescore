import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../reusables/constants.dart';

class AppManagerSignupScreen extends StatefulWidget {
  const AppManagerSignupScreen({super.key});

  @override
  State<AppManagerSignupScreen> createState() => _AppManagerSignupScreenState();
}

class _AppManagerSignupScreenState extends State<AppManagerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isLinkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showAlertDialog({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onButtonPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppTextStyles.subheadingStyle),
        content: Text(message, style: AppTextStyles.bodyStyle),
        actions: [
          TextButton(
            onPressed: onButtonPressed ?? () => Navigator.of(context).pop(),
            child: Text(buttonText, style: AppTextStyles.bodyStyle),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSignInLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (await _authService.isEmailWhitelisted(_emailController.text)) {
        await _authService.sendSignInLinkToEmail(_emailController.text);
        setState(() => _isLinkSent = true);
        _showAlertDialog(
          title: 'Link Sent',
          message: 'A sign-in link has been sent to ${_emailController.text}. Please check your email.',
        );
      } else {
        _showAlertDialog(
          title: 'Access Denied',
          message: 'This email is not whitelisted for signup.',
        );
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        message: 'Failed to send sign-in link: ${e.toString()}. Please try again.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDynamicLink(String emailLink) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential = await _authService.verifyEmailLink(
        _emailController.text,
        emailLink,
      );
      if (credential != null) {
        await _authService.saveUserData({
          'email': _emailController.text,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _showAlertDialog(
          title: 'Success',
          message: 'Signup successful! You will be redirected to login.',
          buttonText: 'Continue',
          onButtonPressed: () {
            Navigator.of(context).pop();
            context.go('/app_manager_login_screen');
          },
        );
      } else {
        _showAlertDialog(
          title: 'Error',
          message: 'Invalid or expired sign-in link. Please request a new one.',
        );
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        message: 'Verification failed: ${e.toString()}. Please try again.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for incoming dynamic link when screen loads
    final uri = GoRouterState.of(context).uri;
    if (FirebaseAuth.instance.isSignInWithEmailLink(uri.toString())) {
      _handleDynamicLink(uri.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: AppColors.secondaryColor,
        title: Text('Admin Dashboard', style: AppTextStyles.headingStyle ),
        backgroundColor: AppColors.primaryColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: AppColors.secondaryColor,
                    child: Text(
                      'REGISTER AS AN ADMIN',
                      style: AppTextStyles.headingStyle.copyWith(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          enabled: !_isLinkSent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendSignInLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.whiteColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.whiteColor)
                        : Text('PROCEED',
                            style: AppTextStyles.subheadingStyle,
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}