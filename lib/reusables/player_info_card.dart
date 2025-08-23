import 'package:flutter/material.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../../models/player_model.dart';
import '../../services/player_service.dart';
import 'custom_dialog.dart';

class PlayerInfoCard extends StatelessWidget {
  final Player player;
  final PlayerService playerService = PlayerService();

  PlayerInfoCard({super.key, required this.player});

  void _deletePlayer(BuildContext context) {
    final navigator = Navigator.of(context);
    CustomDialog.show(
      context,
      title: 'Confirm Deletion',
      message: 'Are you sure you want to delete ${player.name}?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      onConfirm: () async {
        await playerService.deletePlayer(player.id);
        navigator.pop(); // Close the confirmation dialog
        CustomDialog.show(
          // ignore: use_build_context_synchronously
          context,
          title: 'Success',
          message: 'Player deleted successfully',
          confirmText: 'OK',
        );
      },
      onCancel: () {
        navigator.pop();
      },
    );
  }

  void _showEditModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(); // Placeholder for edit form (to be implemented next)
      },
    );
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
                    player.name,
                    style: AppTextStyles.headingStyle,
                  ),
                  const SizedBox(height: 10),
                  if (player.playerPhoto.isNotEmpty)
                    Image.network(
                      player.playerPhoto,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error, color: AppColors.primaryColor);
                      },
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Team: ${player.team ?? 'Not assigned'}',
                    style: AppTextStyles.subheadingStyle,
                  ),
                  Text(
                    'Position: ${player.position}',
                    style: AppTextStyles.subheadingStyle,
                  ),
                  Text(
                    'Jersey No: ${player.jerseyNo}',
                    style: AppTextStyles.subheadingStyle,
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _deletePlayer(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  child: const Text('Delete player'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _showEditModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  child: const Text('Edit player'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}