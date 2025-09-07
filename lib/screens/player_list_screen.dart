import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../../models/player_model.dart';
import '../../services/player_service.dart';
import '../../reusables/player_info_card.dart';
import '../../reusables/custom_progress_indicator.dart'; // Added custom indicator

class PlayerListScreen extends StatefulWidget {
  final PlayerService playerService = PlayerService();

  PlayerListScreen({super.key});

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Player> _filteredPlayers = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          // Filter will be applied in the StreamBuilder
        });
      }
    });
  }

  List<Player> _filterPlayers(List<Player> players, String query) {
    return query.isEmpty
        ? players
        : players.where((player) => player.name.toLowerCase().contains(query.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.push('/admin_panel'), // Navigate back to /admin_panel
        ),
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search players...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: StreamBuilder<List<Player>>(
        stream: widget.playerService.streamPlayers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: AppTextStyles.subheadingStyle));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No players found', style: AppTextStyles.subheadingStyle));
          }

          final players = snapshot.data!;
          _filteredPlayers = _filterPlayers(players, _searchController.text);
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _filteredPlayers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 3.0),
                child: PlayerInfoCard(player: _filteredPlayers[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create_player'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.secondaryColor,
        child: const Icon(Icons.add),
      ),


        bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.exit_to_app),
            label: 'Exit',
          ),
        ],
      ),
    );
  }
}

     