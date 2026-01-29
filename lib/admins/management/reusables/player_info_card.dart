// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/management/models/team_model.dart';
import 'constants.dart';
import '../models/player_model.dart';
import '../services/player_service.dart';
import 'custom_dialog.dart';
import 'edit_player_bottom_sheet.dart';
import '../services/team_service.dart';

class PlayerInfoCard extends StatefulWidget {
  final Player player;
  final PlayerService playerService = PlayerService();
  final TeamService teamService = TeamService();

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
        if (mounted) {
          CustomDialog.show(
            // ignore: use_build_context_synchronously
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

  void _editPlayer(BuildContext context) {
    // Safely open bottom sheet without context disposal error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showEditPlayerBottomSheet(context, widget.player);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Flexible(
              flex: 1,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: widget.player.playerPhoto.isNotEmpty
                    ? NetworkImage(widget.player.playerPhoto)
                    : const AssetImage('assets/person_placeholder.png')
                        as ImageProvider,
                backgroundColor: AppColors.primaryColor,
                child: !widget.player.playerPhoto.isNotEmpty
                    ? const Icon(Icons.person,
                        size: 40, color: AppColors.whiteColor)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            // Player info
            Flexible(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.player.name,
                    style:
                        AppTextStyles.headingStyle.copyWith(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<Team?>(
                    future: widget.player.team != null
                        ? widget.teamService.fetchTeams().then(
                              (teams) => teams.firstWhere(
                                (team) => team.id == widget.player.team,
                                orElse: () => Team(
                                    id: '',
                                    name: '',
                                    abbr: 'N/A',
                                    players: []),
                              ),
                            )
                        : Future.value(null),
                    builder: (context, snapshot) {
                      final teamAbbr = snapshot.data?.abbr ?? 'N/A';
                      final age = widget.player.dateOfBirth != null
                          ? DateTime.now().year -
                              widget.player.dateOfBirth.year
                          : 'N/A';
                      return Text(
                        'Age: $age | Team: $teamAbbr',
                        style: AppTextStyles.subheadingStyle
                            .copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action buttons
            Flexible(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _editPlayer(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: AppColors.whiteColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      minimumSize: const Size(50, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: () => _deletePlayer(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: AppColors.whiteColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      minimumSize: const Size(50, 0),
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
