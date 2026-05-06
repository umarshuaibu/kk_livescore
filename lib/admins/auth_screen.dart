import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:kklivescoreadmin/admins/email_otp_dialog.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';

// ── Design tokens ──
const _kBg = Color(0xFF0F1117);
const _kSurface = Color(0xFF161A23);
const _kSurface2 = Color(0xFF1A1F2E);
const _kBorder = Color(0xFF252B38);
const _kGreen = Color(0xFF81C784);
const _kRed = Color(0xFFE57373);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _isSignup = false;
  bool _obscurePassword = true;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const String _sendOtpUrl =
      'https://sendemailotp-jn5vzghzra-uc.a.run.app';

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
    _slideCtrl.forward();

    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() =>
        setState(() => _passwordFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  //   ORIGINAL LOGIC — UNTOUCHED
  // ════════════════════════════════════════

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
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Email and password required', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      if (!await _isWhitelisted(email)) {
        _showSnack('You are not authorized to access this panel.',
            isError: true);
        return;
      }

      if (_isSignup) {
        await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
        await _auth.signOut();
      }

      await _sendOtp(email);

      if (!mounted) return;
      _showOtpDialog(email);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Auth failed', isError: true);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
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

  void _goToDashboard() => context.go('/admin_panel');

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? _kRed.withOpacity(0.9) : _kSurface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ════════════════════════════════════════
  //   BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Background decoration circles
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor2.withOpacity(0.03),
              ),
            ),
          ),

          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 0,
                    vertical: 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo + Brand
                          _buildBrand(),
                          const SizedBox(height: 36),

                          // Auth card
                          _buildCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BRAND AREA ──
  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.sports_soccer_rounded,
              color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        const Text(
          'KK Livescore',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Admin Panel',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── AUTH CARD ──
  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab switcher
          _buildTabSwitcher(),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            strokeWidth: 2.5),
                        SizedBox(height: 16),
                        Text(
                          'Authenticating...',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : _buildForm(),
          ),
        ],
      ),
    );
  }

  // ── TAB SWITCHER ──
  Widget _buildTabSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          bottom: BorderSide(color: _kBorder),
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _tabBtn(label: 'Login', isActive: !_isSignup,
              onTap: () {
                if (_isSignup) {
                  setState(() => _isSignup = false);
                  _slideCtrl.forward(from: 0);
                }
              }),
          _tabBtn(label: 'Sign Up', isActive: _isSignup,
              onTap: () {
                if (!_isSignup) {
                  setState(() => _isSignup = true);
                  _slideCtrl.forward(from: 0);
                }
              }),
        ],
      ),
    );
  }

  Widget _tabBtn({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryColor2.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(
                    color: AppColors.primaryColor.withOpacity(0.3))
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive
                    ? AppColors.primaryColor2
                    : Colors.grey.shade600,
                fontSize: 13,
                fontWeight: isActive
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── FORM ──
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Heading
        Text(
          _isSignup ? 'Create admin account' : 'Welcome back',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isSignup
              ? 'Your email must be on the authorized list'
              : 'Sign in to manage your league',
          style: TextStyle(
              color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 24),

        // Email
        _buildInputLabel('Email address'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailController,
          focusNode: _emailFocus,
          isFocused: _emailFocused,
          hint: 'admin@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Password
        _buildInputLabel('Password'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          isFocused: _passwordFocused,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          suffix: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey.shade600,
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Submit button
        _buildSubmitButton(),

        const SizedBox(height: 16),

        // Whitelist notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.primaryColor2.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.primaryColor2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Access is restricted to authorized email addresses only.',
                  style: TextStyle(
                      color: AppColors.primaryColor2.withOpacity(0.8),
                      fontSize: 11,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isFocused
            ? AppColors.primaryColor.withOpacity(0.05)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused
              ? AppColors.primaryColor.withOpacity(0.5)
              : _kBorder,
          width: isFocused ? 1.5 : 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.grey.shade700, fontSize: 14),
          prefixIcon:
              Icon(icon, color: Colors.grey.shade600, size: 18),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSignup
                  ? Icons.person_add_rounded
                  : Icons.login_rounded,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              _isSignup ? 'Create Account' : 'Continue',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}