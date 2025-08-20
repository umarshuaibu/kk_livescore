import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../reusables/constants.dart'; // Your constants file

class AppManagerLoginScreen extends StatefulWidget {
  const AppManagerLoginScreen({super.key});

  @override
  State<AppManagerLoginScreen> createState() => _AppManagerLoginScreenState();
}

class _AppManagerLoginScreenState extends State<AppManagerLoginScreen> {
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
          message: 'This email is not whitelisted for login.',
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
        _showAlertDialog(
          title: 'Success',
          message: 'Login successful! You will be redirected.',
          buttonText: 'Continue',
          onButtonPressed: () {
            Navigator.of(context).pop();
            context.go('/app_manager_home_screen'); // Assuming a home screen route
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
    final uri = ModalRoute.of(context)?.settings.arguments as Uri?;
    if (uri != null && FirebaseAuth.instance.isSignInWithEmailLink(uri.toString())) {
      _handleDynamicLink(uri.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      'APP MANAGER LOGIN',
                      style: AppTextStyles.headingStyle.copyWith(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: AppTextStyles.bodyStyle,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    enabled: !_isLinkSent,
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
                        : Text(
                            _isLinkSent ? 'RESEND LINK' : 'PROCEED',
                            style: AppTextStyles.subheadingStyle,
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/app_manager_signup_screen'),
                    child: Text(
                      'Don\'t have an account? Sign Up',
                      style: AppTextStyles.bodyStyle.copyWith(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}