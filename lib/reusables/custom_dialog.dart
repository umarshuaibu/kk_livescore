import 'package:flutter/material.dart';

enum DialogType { success, warning, error }

class CustomDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final DialogType? type; // ✅ new field

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

  /// This helper makes it easier to show the dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = "OK",
    String cancelText = "Cancel",
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    DialogType? type,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CustomDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        type: type,
      ),
    );
  }

  // ✅ helper to get icon & color
  IconData? _getIcon() {
    switch (type) {
      case DialogType.success:
        return Icons.check_circle;
      case DialogType.warning:
        return Icons.warning;
      case DialogType.error:
        return Icons.error;
      default:
        return null;
    }
  }

  Color? _getIconColor() {
    switch (type) {
      case DialogType.success:
        return Colors.green;
      case DialogType.warning:
        return Colors.amber;
      case DialogType.error:
        return Colors.red;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_getIcon() != null) ...[
              Icon(
                _getIcon(),
                size: 48,
                color: _getIconColor(),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: Text(cancelText),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onCancel != null) onCancel!();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  child: Text(confirmText),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onConfirm != null) onConfirm!();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
