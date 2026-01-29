import 'package:flutter/material.dart';
import '../models/transfer_model.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../services/player_service.dart';
import '../services/team_service.dart';

/// A reusable widget to display transfer details in a card format.
///
/// It fetches player and team names based on their IDs in the [Transfer] model.
class PlayerTransferCard extends StatefulWidget {
  final Transfer transfer;

  const PlayerTransferCard({super.key, required this.transfer});

  @override
  State<PlayerTransferCard> createState() => _PlayerTransferCardState();
}

class _PlayerTransferCardState extends State<PlayerTransferCard> {
  final PlayerService _playerService = PlayerService();
  final TeamService _teamService = TeamService();

  Player? _player;
  Team? _oldTeam;
  Team? _newTeam;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final player = await _playerService.fetchPlayerById(context,
      widget.transfer.playerId,);

      Team? oldTeam;
      Team? newTeam;

      oldTeam = await _teamService.fetchTeamById(widget.transfer.oldTeamId);
          if (widget.transfer.newTeamId != null) {
        newTeam = await _teamService.fetchTeamById(widget.transfer.newTeamId!);
      }

  if (!mounted) return; 
      setState(() {
        _player = player;
        _oldTeam = oldTeam;
        _newTeam = newTeam;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error fetching transfer details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player name
                  Text(
                    _player?.name ?? "Unknown Player",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Transfer Type
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 18, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Text(
                        widget.transfer.type,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Old Team
                  if (_oldTeam != null) Row(
                    children: [
                      const Icon(Icons.sports_soccer, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(
                        "From: ${_oldTeam!.name}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),

                  // New Team
                  if (_newTeam != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.sports_soccer, size: 18, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          "To: ${_newTeam!.name}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Date
                  Text(
                    "Date: ${widget.transfer.date.toLocal().toString().split(' ')[0]}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}
