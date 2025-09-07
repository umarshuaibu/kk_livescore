import 'package:flutter/material.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../models/team_model.dart';
import '../services/team_service.dart';
import 'custom_dialog.dart';
import 'edit_team_bottom_sheet.dart';

class TeamInfoCard extends StatelessWidget {
  final Team team;
  final TeamService teamService = TeamService();

  TeamInfoCard({super.key, required this.team});

  void _deleteTeam(BuildContext context) {
    final navigator = Navigator.of(context);
    CustomDialog.show(
      context,
      title: 'Confirm Deletion',
      message: 'Are you sure you want to delete ${team.name}?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      onConfirm: () async {
        await teamService.deleteTeam(team.id);
        navigator.pop(); // Close the confirmation dialog
        await CustomDialog.show(
          // ignore: use_build_context_synchronously
          context,
          title: 'Success',
          message: 'Team deleted successfully',
          confirmText: 'OK',
        );
      },
      onCancel: () {
        navigator.pop();
      },
    );
  }

  void _showEditModal(BuildContext context) {
    showEditTeamBottomSheet(context, team); // Use the helper function
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
                    team.name,
                    style: AppTextStyles.headingStyle,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Abbr: ${team.abbr}',
                    style: AppTextStyles.subheadingStyle,
                  ),
                  const SizedBox(height: 10),
                  if (team.logoUrl != null && team.logoUrl!.isNotEmpty)
                    Image.network(
                      team.logoUrl!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error, color: AppColors.primaryColor);
                      },
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Coach: ${team.coachId ?? 'Not assigned'}',
                    style: AppTextStyles.subheadingStyle,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Players: ${team.players.isEmpty ? 'None' : team.players.join(', ')}',
                    style: AppTextStyles.subheadingStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _deleteTeam(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  child: const Text('Delete team'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _showEditModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  child: const Text('Edit team'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}