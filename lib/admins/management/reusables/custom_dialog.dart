import 'dart:ui';
import 'package:flutter/material.dart';


enum DialogType { success, warning, error, info }

class CustomDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final DialogType? type;

  const CustomDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = "OK",
    this.cancelText = "Cancel",
    this.onConfirm,
    this.onCancel,
    this.type,
  });

  // ignore: unintended_html_in_doc_comment
  /// ⭐ Now returns Future<bool?> so it can confirm or cancel.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = "OK",
    String cancelText = "Cancel",
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    DialogType? type,
  }) {
return showGeneralDialog<bool>(
context: context,   // ✔ FIXED — safe and not null
  barrierDismissible: false,
  barrierLabel: '',
  transitionDuration: const Duration(milliseconds: 240),
  pageBuilder: (_, __, ___) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // ⭐ subtle blur
      child: Container(),
    );
  },
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    return Transform.scale(
      scale: Curves.easeOutBack.transform(animation.value),
      child: Opacity(
        opacity: animation.value,
        child: Dialog(
          // ignore: deprecated_member_use
          backgroundColor: Colors.white.withOpacity(0.92), // frosted look
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: CustomDialog(
              title: title,
              message: message,
              confirmText: confirmText,
              cancelText: cancelText,
              onConfirm: onConfirm,
              onCancel: onCancel,
              type: type,
            ),
          ),
        ),
      ),
    );
  },
);
  }

  IconData? _getIcon() {
    switch (type) {
      case DialogType.success:
        return Icons.check_circle_rounded;
      case DialogType.warning:
        return Icons.warning_amber_rounded;
      case DialogType.error:
        return Icons.error_rounded;
      default:
        return null;
    }
  }

  Color? _getIconColor() {
    switch (type) {
      case DialogType.success:
        return Colors.green.shade600;
      case DialogType.warning:
        return Colors.orange.shade700;
      case DialogType.error:
        return Colors.red.shade600;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_getIcon() != null) ...[
          Icon(_getIcon(), size: 50, color: _getIconColor()),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16.2,
            color: Colors.grey[800],
            height: 1.35,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // CANCEL = false
            TextButton(
              child: Text(
                cancelText,
                style: TextStyle(color: Colors.grey[700]),
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
                if (onCancel != null) onCancel!();
              },
            ),
            const SizedBox(width: 10),
            // CONFIRM = true
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(confirmText),
              onPressed: () {
                Navigator.of(context).pop(true);
                if (onConfirm != null) onConfirm!();
              },
            ),
          ],
        ),
      ],
    );
  }
}
