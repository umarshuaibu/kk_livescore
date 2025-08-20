import 'package:flutter/material.dart';
import '../reusables/colors_and_text_styles.dart';

class ReusableCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ReusableCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: imageUrl != null
            ? CircleAvatar(
                backgroundImage: NetworkImage(imageUrl!),
                radius: 24,
              )
            : const Icon(Icons.image, size: 48),
        title: Text(title, style: AppTextStyles.headingStyle),
        subtitle: subtitle != null ? Text(subtitle!, style: AppTextStyles.bodyStyle) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}