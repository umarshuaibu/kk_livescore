import 'package:flutter/material.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../models/coach_model.dart';
import '../services/coach_service.dart';
import 'custom_dialog.dart';
import 'edit_coach_bottom_sheet.dart';

class CoachInfoCard extends StatelessWidget {
  final Coach coach;
  final CoachService coachService = CoachService();

  CoachInfoCard({super.key, required this.coach});

  void _deleteCoach(BuildContext context) {
    final navigator = Navigator.of(context);
    CustomDialog.show(
      context,
      title: 'Confirm Deletion',
      message: 'Are you sure you want to delete ${coach.name}?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      onConfirm: () async {
        await coachService.deleteCoach(coach.id);
        navigator.pop(); // Close the confirmation dialog
        await CustomDialog.show(
          // ignore: use_build_context_synchronously
          context,
          title: 'Success',
          message: 'Coach deleted successfully',
          confirmText: 'OK',
        );
      },
      onCancel: () {
        navigator.pop();
      },
    );
  }

  void _showEditModal(BuildContext context) {
    showEditCoachBottomSheet(context, coach); // Use the helper function
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coach.name,
                    style: AppTextStyles.headingStyle,
                  ),
                  const SizedBox(height: 10),
                  if (coach.photoUrl != null && coach.photoUrl!.isNotEmpty)
                    Image.network(
                      coach.photoUrl!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error, color: AppColors.primaryColor);
                      },
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Team: ${coach.team ?? 'Not assigned'}',
                    style: AppTextStyles.subheadingStyle,
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _deleteCoach(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  child: const Text('Delete coach'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _showEditModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  child: const Text('Edit coach'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}