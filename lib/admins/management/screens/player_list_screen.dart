import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/app_manager/admin_body_view.dart';
import 'package:kklivescoreadmin/admins/management/reusables/player_table_row.dart';
import '../reusables/constants.dart';
import '../models/player_model.dart';
import '../services/player_service.dart';
import '../reusables/custom_progress_indicator.dart';
import '../reusables/custom_dialog.dart';

class PlayerListScreen extends StatefulWidget {
  final PlayerService playerService = PlayerService();
  final void Function(AdminBodyView view, {Player? player}) onNavigate;

  PlayerListScreen({
    super.key,
    required this.onNavigate,
  });

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
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() {});
    });
  }

  List<Player> _filterPlayers(List<Player> players, String query) {
    if (query.isEmpty) return players;

    return players
        .where(
          (p) => p.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  Future<void> _deletePlayer(Player player) async {
    final confirm = await CustomDialog.show(
      context,
      title: 'Confirm Delete',
      message: 'Are you sure you want to delete ${player.name}?',
      type: DialogType.warning,
    );

    if (confirm != true) return;

    try {
      await widget.playerService.deletePlayer(player.id);

      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Deleted',
        message: '${player.name} has been deleted.',
        type: DialogType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Error',
        message: 'Failed to delete player: $e',
        type: DialogType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin_panel'),
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
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: AppTextStyles.subheadingStyle,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No players found',
                style: AppTextStyles.subheadingStyle,
              ),
            );
          }

          final players = snapshot.data!;
          _filteredPlayers =
              _filterPlayers(players, _searchController.text);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Team')),
                  DataColumn(label: Text('State')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _filteredPlayers.map(
                  (player) {
                    return buildPlayerDataRow(
                      player: player,
                      onEdit: (p) {
                        // ✅ GoRouter-safe navigation (ID only)
                        context.go(
                          '/edit_player',
                          extra: p.id,
                        );
                      },
                      onTransfer: (p) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Transfer Player'),
                            content: Text(
                              'Transfer ${p.name} to another team?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  // TODO: transfer logic
                                  Navigator.pop(context);
                                },
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDelete: (p) => _deletePlayer(p),
                    );
                  },
                ).toList(),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          widget.onNavigate(AdminBodyView.createPlayer);
        },
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.secondaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
