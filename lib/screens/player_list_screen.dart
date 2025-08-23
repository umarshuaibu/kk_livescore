import 'package:flutter/material.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../../models/player_model.dart';
import '../../services/player_service.dart';
import '../../reusables/player_info_card.dart';

class PlayerListScreen extends StatelessWidget {
  final PlayerService playerService = PlayerService();

PlayerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Player>>(
      stream: playerService.streamPlayers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: AppTextStyles.subheadingStyle));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No players found', style: AppTextStyles.subheadingStyle));
        }

        final players = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: players.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: PlayerInfoCard(player: players[index]),
            );
          },
        );
      },
    );
  }
}