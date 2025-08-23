import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../reusables/constants.dart';

class AppManagerLoginScreen extends StatefulWidget {
  final String? token; // Token from deep link
  const AppManagerLoginScreen({super.key, this.token});

  @override
  State<AppManagerLoginScreen> createState() => _AppManagerLoginScreenState();
}

class _AppManagerLoginScreenState extends State<AppManagerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _hasProcessedLink = false; // Prevent multiple deep link processing

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
            onPressed: onButtonPressed ?? () => context.pop(), // Use go_router's pop
            child: Text(
              buttonText,
              style: AppTextStyles.bodyStyle,
              semanticsLabel: buttonText, // Accessibility support
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasswordlessSignIn(String email, String emailLink) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential = await _authService.verifyEmailLink(email, emailLink);
      if (credential != null) {
        await _authService.saveUserData({
          'email': email,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _showAlertDialog(
          title: 'Success',
          message: 'Login successful! You will be redirected to the dashboard.',
          buttonText: 'Continue',
          onButtonPressed: () {
            context.pop(); // Close dialog
            context.go(AppRoutes.adminDashboard); // Navigate with go_router
          },
        );
      } else {
        _showAlertDialog(
          title: 'Error',
          message: 'Invalid or expired sign-in link. Please request a new one.',
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'expired-action-code':
          errorMessage = 'The sign-in link has expired. Please request a new one.';
          break;
        case 'invalid-action-code':
          errorMessage = 'The sign-in link is invalid. Please request a new one.';
          break;
        default:
          errorMessage = 'Login failed. Please try again.';
      }
      _showAlertDialog(
        title: 'Error',
        message: errorMessage,
      );
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        message: 'An unexpected error occurred. Please try again.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Handle deep link only once and if email is provided
    if (widget.token != null && !_hasProcessedLink && _emailController.text.isNotEmpty) {
      setState(() => _hasProcessedLink = true); // Prevent reprocessing
      final uri = GoRouterState.of(context).uri; // Use go_router's URI
      final email = _emailController.text.trim(); // Sanitize input
      final emailLink = uri.toString();
      if (FirebaseAuth.instance.isSignInWithEmailLink(emailLink)) {
        _handlePasswordlessSignIn(email, emailLink);
      } else {
        _showAlertDialog(
          title: 'Invalid Link',
          message: 'The sign-in link is invalid. Please request a new one.',
        );
      }
    } else if (widget.token != null && _emailController.text.isEmpty) {
      _showAlertDialog(
        title: 'Email Required',
        message: 'Please enter your email to proceed with the sign-in link.',
      );
    }
  }

  Future<void> _sendSignInLink() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim(); // Sanitize input
    setState(() => _isLoading = true);
    try {
      if (await _authService.isEmailWhitelisted(email)) {
        await _authService.sendSignInLinkToEmail(email);
        _showAlertDialog(
          title: 'Link Sent',
          message: 'A sign-in link has been sent to $email. Please check your email. The link expires in 30 minutes.',
        );
      } else {
        _showAlertDialog(
          title: 'Access Denied',
          message: 'This email is not authorized for admin login.',
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        default:
          errorMessage = 'Failed to send sign-in link. Please try again.';
      }
      _showAlertDialog(
        title: 'Error',
        message: errorMessage,
      );
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        message: 'An unexpected error occurred. Please try again.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: AppColors.secondaryColor,
        title: Text(
          'Admin Login',
          style: AppTextStyles.headingStyle,
          semanticsLabel: 'Admin Login', // Accessibility support
        ),
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
                      'LOGIN AS AN ADMIN',
                      style: AppTextStyles.headingStyle.copyWith(
                        color: AppColors.primaryColor,
                      ),
                      semanticsLabel: 'Login as an Admin', // Accessibility
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
                          textInputAction: TextInputAction.done, // Keyboard navigation
                          autofillHints: const [AutofillHints.email], // Autofill support
                          validator: (value) {
                            value = value?.trim() ?? ''; // Sanitize input
                            if (value.isEmpty) {
                              return 'Please enter email';
                            }
                            // Updated regex for broader email format support
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _sendSignInLink(), // Submit on Enter
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
                        : Text(
                            'PROCEED',
                            style: AppTextStyles.subheadingStyle,
                            semanticsLabel: 'Proceed', // Accessibility
                          ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Processing...',
                      style: AppTextStyles.bodyStyle,
                      semanticsLabel: 'Processing', // Accessibility
                    ),
                  ],
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

// Example constants file (assumed to exist)
class AppRoutes {
  static const String adminDashboard = '/admin_dashboard';
}