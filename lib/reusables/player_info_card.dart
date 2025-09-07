// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/models/team_model.dart';
import '/reusables/constants.dart'; // Adjust import path based on your structure
import '../../models/player_model.dart';
import '../../services/player_service.dart';
import 'custom_dialog.dart'; // Updated import
import 'edit_player_bottom_sheet.dart';
import '../../services/team_service.dart'; // Added for team abbreviation

class PlayerInfoCard extends StatefulWidget {
  final Player player;
  final PlayerService playerService = PlayerService();
  final TeamService teamService = TeamService(); // Added for team lookup

  PlayerInfoCard({super.key, required this.player});

  @override
  State<PlayerInfoCard> createState() => _PlayerInfoCardState();
}

class _PlayerInfoCardState extends State<PlayerInfoCard> {
  void _deletePlayer(BuildContext context) {
    CustomDialog.show(
      context,
      title: 'Confirm Deletion',
      message: 'Are you sure you want to delete ${widget.player.name}?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      onConfirm: () async {
        await widget.playerService.deletePlayer(widget.player.id);
        if (mounted) {// Close the confirmation dialog
          CustomDialog.show(
            context,
            title: 'Success',
            message: 'Player deleted successfully',
            confirmText: 'OK',
            type: DialogType.success,
            onConfirm: () => context.go('/player_list'),
          );
        }
      },
      onCancel: () {
        if (mounted) {
          context.go('/player_list');
        }
      },
      type: DialogType.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0), // Uniform top/bottom margin
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center, // Center vertically
          children: [
            // First Column: Player Photo (Circular Avatar, 1 part)
            Flexible(
              flex: 1,
              child: CircleAvatar(
                radius: 40, // Ensures a perfect circle (80x80)
                backgroundImage: widget.player.playerPhoto.isNotEmpty
                    ? NetworkImage(widget.player.playerPhoto)
                    : const AssetImage('assets/person_placeholder.png') as ImageProvider,
                backgroundColor: AppColors.primaryColor,
                child: !widget.player.playerPhoto.isNotEmpty
                    ? const Icon(Icons.person, size: 40, color: AppColors.whiteColor)
                    : null, // Show icon only if no image
              ),
            ),
            const SizedBox(width: 8), // Reduced spacer between columns
            // Second Column: Player Name and Age/Team Abbr (3 parts)
            Flexible(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First Row: Player Name
                  Text(
                    widget.player.name,
                    style: AppTextStyles.headingStyle.copyWith(fontSize: 16), // Reduced font size
                    overflow: TextOverflow.ellipsis, // Prevent overflow
                  ),
                  const SizedBox(height: 4), // Reduced spacer between rows
                  // Second Row: Age and Team Abbreviation
                  FutureBuilder<Team?>(
                    future: widget.player.team != null
                        ? widget.teamService.fetchTeams().then((teams) => teams.firstWhere(
                              (team) => team.id == widget.player.team,
                              orElse: () => Team(id: '', name: '', abbr: 'N/A', players: []),
                            ))
                        : Future.value(null),
                    builder: (context, snapshot) {
                      final teamAbbr = snapshot.data?.abbr ?? 'N/A';
                      final age = widget.player.dateOfBirth != null
                          ? DateTime.now().year - widget.player.dateOfBirth.year
                          : 'N/A';
                      return Text(
                        'Age: $age | Team: $teamAbbr',
                        style: AppTextStyles.subheadingStyle.copyWith(fontSize: 12), // Reduced font size
                        overflow: TextOverflow.ellipsis, // Prevent overflow
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8), // Reduced spacer between columns
            // Third Column: Edit and Delete Buttons (1 part)
            Flexible(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                children: [
                  // First Row: Edit Button
                  ElevatedButton(
                    onPressed: () => showEditPlayerBottomSheet(context, widget.player),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: AppColors.whiteColor,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      minimumSize: const Size(50, 0), // Fixed width for both buttons
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4), // Reduced padding between buttons
                  // Second Row: Delete Button
                  ElevatedButton(
                    onPressed: () => _deletePlayer(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: AppColors.whiteColor,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      minimumSize: const Size(50, 0), // Fixed width for both buttons
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}