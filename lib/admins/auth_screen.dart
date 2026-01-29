import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _smsCodeController = TextEditingController();

  bool _loading = false;
  bool _usePhone = false;
  bool _isSignup = false;

  String _verificationId = '';

// ================= WHITELIST CHECK (QUERY BASED, SAFE FOR WEB) =================
Future<bool> _isWhitelisted({String? email, String? phone}) async {
  try {
    final whitelistRef = _firestore.collection('whitelist');
    Query query;

    // Build query based on email or phone
    if (email != null && email.trim().isNotEmpty) {
      query = whitelistRef.where('email', isEqualTo: email.trim());
    } else if (phone != null && phone.trim().isNotEmpty) {
      query = whitelistRef.where('phone', isEqualTo: phone.trim());
    } else {
      return false;
    }

    // Attempt to get the document
    final snap = await query.limit(1).get();

    // Return true if found, false otherwise
    return snap.docs.isNotEmpty;

  } catch (e, stackTrace) {
    // Catch and print any errors
    debugPrint('Whitelist check error: $e');
    debugPrint('Stack trace: $stackTrace');

    // Return false if an error occurs
    return false;
  }
}


  // ================= EMAIL AUTH =================
  Future<void> _handleEmailAuth() async {
    final email = _emailOrPhoneController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password required');
      return;
    }

    setState(() => _loading = true);

    try {
      final allowed = await _isWhitelisted(email: email);
      if (!allowed) {
        _showError('You are not authorized to access this system');
        return;
      }

      if (_isSignup) {
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      _goToDashboard();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= PHONE AUTH =================
  Future<void> _handlePhoneAuth() async {
    final phone = _emailOrPhoneController.text.trim();

    if (phone.isEmpty) {
      _showError('Phone number required');
      return;
    }

    setState(() => _loading = true);

    try {
      final allowed = await _isWhitelisted(phone: phone);
      if (!allowed) {
        _showError('You are not authorized to access this system');
        return;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await _auth.signInWithCredential(credential);
          _goToDashboard();
        },
        verificationFailed: (e) {
          _showError(e.message ?? 'Verification failed');
        },
        codeSent: (id, _) {
          _verificationId = id;
          _showSMSDialog();
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifySMS() async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _smsCodeController.text.trim(),
      );

      await _auth.signInWithCredential(credential);
      _goToDashboard();
    } catch (_) {
      _showError('Invalid SMS code');
    }
  }

  // ================= NAVIGATION =================
  void _goToDashboard() {
    if (mounted) context.go('/admin_panel');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 600 ? 420.0 : width * 0.9;

    return Scaffold(
      backgroundColor: kSecondaryColor,
      body: Center(
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: cardWidth,
            child: Padding(
              padding: EdgeInsets.all(eqW(20)),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isSignup ? 'Admin Sign Up' : 'Admin Sign In',
                          style: kText12Secondary.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: eqW(16)),

                        SwitchListTile(
                          value: _usePhone,
                          onChanged: (v) => setState(() => _usePhone = v),
                          title: Text(_usePhone ? 'Use Phone' : 'Use Email'),
                        ),

                        TextField(
                          controller: _emailOrPhoneController,
                          decoration: InputDecoration(
                            labelText: _usePhone ? 'Phone Number' : 'Email',
                          ),
                        ),

                        if (!_usePhone) ...[
                          SizedBox(height: eqW(12)),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Password'),
                          ),
                        ],

                        SizedBox(height: eqW(20)),
                        PrimaryButton(
                          text: _isSignup ? 'Create Account' : 'Login',
                          onPressed: _usePhone ? _handlePhoneAuth : _handleEmailAuth,
                          height: eqW(48),
                        ),

                        SizedBox(height: eqW(12)),
                        TextButton(
                          onPressed: () => setState(() => _isSignup = !_isSignup),
                          child: Text(
                            _isSignup
                                ? 'Already have an account? Sign In'
                                : 'New admin? Sign Up',
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

  void _showSMSDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter SMS Code'),
        content: TextField(
          controller: _smsCodeController,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _verifySMS();
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }
}
