import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class _EmailOtpDialogState extends State<EmailOtpDialog> {
  final _otpController = TextEditingController();
  bool _loading = false;
  int _resendSeconds = 60;
  Timer? _timer;

static const String _verifyOtpUrl =
    'https://verifyemailotp-jn5vzghzra-uc.a.run.app';

  @override
  void initState() {
    super.initState();
    _startResendTimer();
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

  

  Future<void> _verifyOtp() async {
    setState(() => _loading = true);

    final res = await http.post(
      Uri.parse(_verifyOtpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': widget.email,
        'code': _otpController.text.trim(),
      }),
    );

    setState(() => _loading = false);

    if (res.statusCode == 200) {
      Navigator.pop(context);
      widget.onVerified();
    } else {
      _showError('Invalid or expired OTP');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify Email OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('OTP sent to ${widget.email}'),
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '6-digit OTP'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _resendSeconds == 0
              ? () async {
                  await widget.resendOtp();
                  _startResendTimer();
                }
              : null,
          child: Text(
            _resendSeconds == 0
                ? 'Resend OTP'
                : 'Resend in $_resendSeconds s',
          ),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _verifyOtp,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
