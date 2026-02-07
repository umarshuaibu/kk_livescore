import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:kklivescoreadmin/admins/email_otp_dialog.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';
import 'package:kklivescoreadmin/constants/buttons.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _isSignup = false;

  static const String _sendOtpUrl =
      'https://sendemailotp-jn5vzghzra-uc.a.run.app';

  Future<bool> _isWhitelisted(String email) async {
    final snap = await _firestore
        .collection('whitelist')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _sendOtp(String email) async {
    final res = await http.post(
      Uri.parse(_sendOtpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password required');
      return;
    }

    setState(() => _loading = true);

    try {
      if (!await _isWhitelisted(email)) {
        _showError('You are not authorized');
        return;
      }

      if (_isSignup) {
        // 🆕 SIGNUP
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await _auth.signOut();
      }

      // Send OTP for both login & signup
      await _sendOtp(email);

      if (!mounted) return;
      _showOtpDialog(email);

    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Auth failed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOtpDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmailOtpDialog(
        email: email,
        onVerified: () async {
          await _auth.signInWithEmailAndPassword(
            email: email,
            password: _passwordController.text.trim(),
          );
          _goToDashboard();
        },
        resendOtp: () => _sendOtp(email),
      ),
    );
  }

  void _goToDashboard() {
    context.go('/admin_panel');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSecondaryColor,
      body: Center(
        child: Card(
          elevation: 10,
          child: SizedBox(
            width: 420,
            child: Padding(
              padding: EdgeInsets.all(eqW(20)),
              child: _loading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isSignup ? 'Admin Signup' : 'Admin Login',
                          style: kText12Secondary.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: eqW(20)),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        SizedBox(height: eqW(12)),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                        ),
                        SizedBox(height: eqW(20)),
                        PrimaryButton(
                          text: _isSignup ? 'Signup' : 'Login',
                          onPressed: _handleSubmit,
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _isSignup = !_isSignup),
                          child: Text(
                            _isSignup
                                ? 'Already have an account? Login'
                                : 'New admin? Signup',
                          ),
                        )
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
