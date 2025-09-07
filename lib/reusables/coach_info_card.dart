import 'package:flutter/material.dart';
import 'constants.dart';
import '../services/coach_service.dart';
import '../models/coach_model.dart';
import 'edit_coach_bottom_sheet.dart'; 
import 'custom_dialog.dart'; // ✅ import dialog
import 'package:cloud_firestore/cloud_firestore.dart';

class CoachInfoCard extends StatelessWidget {
  final Coach coach;
  final CoachService _coachService = CoachService();

  CoachInfoCard({super.key, required this.coach});

  int _calculateAge(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  Future<void> _deleteCoach(BuildContext context) async {
    if (coach.id.isEmpty) {
      if (context.mounted) {
        CustomDialog.show(
          context,
          title: "Error",
          message: "Invalid coach ID",
          type: DialogType.error,
        );
      }
      return;
    }
    try {
      if (coach.teamId != null) {
        await FirebaseFirestore.instance.collection('teams')
            .doc(coach.teamId)
            .update({'coachId': FieldValue.delete()})
            .catchError((e) => CustomDialog.show(
                  // ignore: use_build_context_synchronously
                  context,
                  title: 'Error',
                  message: 'Failed to clear coachId: $e',
                  type: DialogType.error,
                ));
      }
      await _coachService.deleteCoach(coach.id);
      if (context.mounted) {
        CustomDialog.show(
          context,
          title: "Success",
          message: "${coach.name} deleted successfully",
          type: DialogType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomDialog.show(
          context,
          title: "Error",
          message: "Failed to delete coach: $e",
          type: DialogType.error,
        );
      }
    }
  }

  void _editCoach(BuildContext context) {
    showEditCoachBottomSheet(context, coach);
  }

  @override
  Widget build(BuildContext context) {
    int age = _calculateAge(coach.dateOfBirth);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 35,
                backgroundImage: coach.photoUrl != null && coach.photoUrl!.isNotEmpty
                    ? NetworkImage(coach.photoUrl!)
                    : null,
                child: coach.photoUrl == null || coach.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              title: Text(
                coach.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (coach.teamId != null && coach.teamName != null)
                    Text(
                      "Team: ${coach.teamName}",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    )
                  else if (coach.teamId != null)
                    Text(
                      "Team: Not specified",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  Text(
                    "Age: ${age > 0 ? age.toString() : 'N/A'}",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1, height: 20),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () {
                      CustomDialog.show(
                        context,
                        title: "Confirm Delete",
                        message: "Are you sure you want to delete ${coach.name}?",
                        confirmText: "Delete",
                        cancelText: "Cancel",
                        type: DialogType.warning,
                        onConfirm: () => _deleteCoach(context),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () => _editCoach(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}