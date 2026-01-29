import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/transfer_model.dart';
import '../services/player_service.dart';
import '../services/team_service.dart';
import '../services/transfer_service.dart';
import '../reusables/constants.dart';
import '../reusables/custom_dialog.dart';

class PlayerTransferScreen extends StatefulWidget {
  const PlayerTransferScreen({super.key});

  @override
  State<PlayerTransferScreen> createState() => _PlayerTransferScreenState();
}

class _PlayerTransferScreenState extends State<PlayerTransferScreen> {
  final TeamService _teamService = TeamService();
  final PlayerService _playerService = PlayerService();
  final TransferService _transferService = TransferService();

  String? _selectedOldTeamId;
  String? _selectedPlayerId;
  String? _transferType;
  String? _selectedNewTeamId;

  List<Team> _teams = [];
  List<Player> _players = [];

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final teams = await _teamService.fetchTeams();
    if (mounted) {
      setState(() {
        _teams = teams;
      });
    }
  }

  Future<void> _loadPlayers(String teamId) async {
    final players = await _playerService.fetchPlayersByTeam(teamId);
    if (mounted) {
      setState(() {
        _players = players;
        _selectedPlayerId = null; // reset when changing team
      });
    }
  }

  Future<void> _handleConfirm() async {
    if (_selectedOldTeamId == null || _selectedPlayerId == null || _transferType == null) {
      CustomDialog.show(context,
          title: "Error", message: "Please complete all required fields", type: DialogType.error);
      return;
    }

    final player = _players.firstWhere((p) => p.id == _selectedPlayerId);

    try {
      if (_transferType == "Release") {
        // 1. Clear team from player
        await FirebaseFirestore.instance.collection('players').doc(player.id).update({
          'team': FieldValue.delete(),
        });

        // 2. Remove player from old team
        await FirebaseFirestore.instance.collection('teams').doc(_selectedOldTeamId).update({
          'players': FieldValue.arrayRemove([player.id]),
        });
      } else if (_transferType == "Delete") {
        // 1. Remove player from old team
        await FirebaseFirestore.instance.collection('teams').doc(_selectedOldTeamId).update({
          'players': FieldValue.arrayRemove([player.id]),
        });

        // 2. Delete player
        await FirebaseFirestore.instance.collection('players').doc(player.id).delete();
      } else if (_transferType == "Transfer") {
        if (_selectedNewTeamId == null) {
           if (mounted){
          CustomDialog.show(context,
              title: "Error", message: "Please select a new team", type: DialogType.error);
          return;
        }
      }

        // 1. Remove player from old team
        await FirebaseFirestore.instance.collection('teams').doc(_selectedOldTeamId).update({
          'players': FieldValue.arrayRemove([player.id]),
        });

        // 2. Add player to new team
        await FirebaseFirestore.instance.collection('teams').doc(_selectedNewTeamId).update({
          'players': FieldValue.arrayUnion([player.id]),
        });

        // 3. Update player with new team
        await FirebaseFirestore.instance.collection('players').doc(player.id).update({
          'team': _selectedNewTeamId,
        });
      }

      // ✅ Record transfer in transfers collection
      await _transferService.addTransfer(
        Transfer(
          id: '',
          playerId: player.id,
          oldTeamId: _selectedOldTeamId!,
          newTeamId: _transferType == "Transfer" ? _selectedNewTeamId : null,
          type: _transferType!,
          timestamp: DateTime.now(),
          initiatedBy: "admin", // Replace with real admin id if available
        ),
      );

      if (mounted) {
        CustomDialog.show(context,
            title: "Success",
            message: "Player transfer completed successfully",
            type: DialogType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomDialog.show(context,
            title: "Error", message: "Failed to complete transfer: $e", type: DialogType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Player Transfer"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 4,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Old Team Dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Select Old Team"),
                  value: _selectedOldTeamId,
                  items: _teams
                      .map((team) =>
                          DropdownMenuItem(value: team.id, child: Text(team.name)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOldTeamId = value;
                      if (value != null) {
                        _loadPlayers(value);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Player Dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Select Player"),
                  value: _selectedPlayerId,
                  items: _players
                      .map((player) =>
                          DropdownMenuItem(value: player.id, child: Text(player.name)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPlayerId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Transfer Type (Radio Buttons)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Transfer Type:"),
                    RadioListTile<String>(
                      title: const Text("Release"),
                      value: "Release",
                      groupValue: _transferType,
                      onChanged: (value) => setState(() => _transferType = value),
                    ),
                    RadioListTile<String>(
                      title: const Text("Delete player"),
                      value: "Delete",
                      groupValue: _transferType,
                      onChanged: (value) => setState(() => _transferType = value),
                    ),
                    RadioListTile<String>(
                      title: const Text("Transfer to another team"),
                      value: "Transfer",
                      groupValue: _transferType,
                      onChanged: (value) => setState(() => _transferType = value),
                    ),
                  ],
                ),

                // New Team Dropdown (only for Transfer)
                if (_transferType == "Transfer")
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Select New Team"),

                    // ✅ Check only against the filtered items
                    value: _teams
                            .where((t) => t.id != _selectedOldTeamId)
                            .any((t) => t.id == _selectedNewTeamId)
                        ? _selectedNewTeamId
                        : null,

                    items: _teams
                        .where((t) => t.id != _selectedOldTeamId)
                        .map((team) =>
                            DropdownMenuItem(value: team.id, child: Text(team.name)))
                        .toList(),

                    onChanged: (value) {
                      setState(() {
                        _selectedNewTeamId = value;
                      });
                    },
                  ),

                const SizedBox(height: 20),

                // Confirm Button
                ElevatedButton(
                  onPressed: _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  ),
                  child: const Text("Confirm"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
