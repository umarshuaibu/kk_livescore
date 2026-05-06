import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';

// ── Design tokens ──
const _kSurface = Color(0xFF161A23);
const _kSurface2 = Color(0xFF1A1F2E);
const _kBorder = Color(0xFF252B38);
const _kGreen = Color(0xFF81C784);
const _kRed = Color(0xFFE57373);
const _kAmber = Color(0xFFFFB74D);

class EmailOtpDialog extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;
  final Future<void> Function() resendOtp;

  const EmailOtpDialog({
    super.key,
    required this.email,
    required this.onVerified,
    required this.resendOtp,
  });

  @override
  State<EmailOtpDialog> createState() => _EmailOtpDialogState();
}

class _EmailOtpDialogState extends State<EmailOtpDialog>
    with SingleTickerProviderStateMixin {
  // 6 individual digit controllers
  final List<TextEditingController> _digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  bool _verifyError = false;
  int _resendSeconds = 60;
  Timer? _timer;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  static const String _verifyOtpUrl =
      'https://verifyemailotp-jn5vzghzra-uc.a.run.app';

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
        parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _fullOtp =>
      _digitControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Auto-submit when all 6 filled
        if (_fullOtp.length == 6) _verifyOtp();
      }
    } else if (value.isEmpty && index > 0) {
      // Move back on delete
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _verifyError = false);
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _digitControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _fullOtp;
    if (otp.length < 6) {
      _showSnack('Please enter all 6 digits', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _verifyError = false;
    });

    try {
      final res = await http.post(
        Uri.parse(_verifyOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'code': otp}),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          widget.onVerified();
        }
      } else {
        setState(() => _verifyError = true);
        _shakeCtrl.forward(from: 0);
        _showSnack('Invalid or expired OTP', isError: true);
        // Clear inputs on error
        for (final c in _digitControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      _showSnack('Verification failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResend() async {
    setState(() => _resending = true);
    try {
      await widget.resendOtp();
      _startResendTimer();
      _showSnack('OTP resent successfully');
      for (final c in _digitControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } catch (e) {
      _showSnack('Failed to resend OTP', isError: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? _kRed.withOpacity(0.9) : _kSurface2,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                children: [
                  // Email sent to
                  _buildEmailBadge(),
                  const SizedBox(height: 28),

                  // OTP input boxes
                  _buildOtpInputs(),
                  const SizedBox(height: 24),

                  // Verify button
                  _buildVerifyButton(),
                  const SizedBox(height: 16),

                  // Resend
                  _buildResendRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.mark_email_read_rounded,
                color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email Verification',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Enter the 6-digit code we sent you',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white60, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ── EMAIL BADGE ──
  Widget _buildEmailBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.email_outlined,
              size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(
            widget.email,
            style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── OTP INPUT BOXES ──
  Widget _buildOtpInputs() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (index) {
          return _OtpDigitBox(
            controller: _digitControllers[index],
            focusNode: _focusNodes[index],
            hasError: _verifyError,
            onChanged: (v) => _onDigitChanged(index, v),
            onKeyEvent: (e) => _onKeyEvent(index, e),
          );
        }),
      ),
    );
  }

  // ── VERIFY BUTTON ──
  Widget _buildVerifyButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          disabledBackgroundColor:
              AppColors.primaryColor.withOpacity(0.35),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13)),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Verify Code',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  // ── RESEND ROW ──
  Widget _buildResendRow() {
    final canResend = _resendSeconds == 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Didn't receive the code? ",
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12)),
        GestureDetector(
          onTap: canResend && !_resending ? _handleResend : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: _resending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4FC3F7)))
                : Text(
                    canResend
                        ? 'Resend'
                        : 'Resend in ${_resendSeconds}s',
                    style: TextStyle(
                      color: canResend
                          ? AppColors.primaryColor
                          : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: canResend
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   SINGLE OTP DIGIT BOX
// ════════════════════════════════════════════════════════════════════
class _OtpDigitBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  const _OtpDigitBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  State<_OtpDigitBox> createState() => _OtpDigitBoxState();
}

class _OtpDigitBoxState extends State<_OtpDigitBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(
        () => setState(() => _focused = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: widget.onKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 54,
        decoration: BoxDecoration(
          color: _focused
              ? AppColors.primaryColor.withOpacity(0.08)
              : hasValue
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.hasError
                ? _kRed.withOpacity(0.6)
                : _focused
                    ? AppColors.primaryColor.withOpacity(0.6)
                    : hasValue
                        ? AppColors.primaryColor.withOpacity(0.25)
                        : const Color(0xFF252B38),
            width: _focused ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: TextStyle(
              color: widget.hasError ? _kRed : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            onChanged: widget.onChanged,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}