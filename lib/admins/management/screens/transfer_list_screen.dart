import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../reusables/constants.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';
import '../reusables/custom_progress_indicator.dart';
import '../reusables/player_transfer_card.dart';

class TransferListScreen extends StatefulWidget {
  final TransferService transferService = TransferService();

  TransferListScreen({super.key});

  @override
  State<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferListScreenState extends State<TransferListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Transfer> _filteredTransfers = [];

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
          // Filtering happens in the StreamBuilder
        });
      }
    });
  }

  List<Transfer> _filterTransfers(List<Transfer> transfers, String query) {
    return query.isEmpty
        ? transfers
        : transfers.where((transfer) {
            final q = query.toLowerCase();
            return transfer.type.toLowerCase().contains(q) ||
                   transfer.playerId.toLowerCase().contains(q) ||
                   transfer.oldTeamId.toLowerCase().contains(q) ||
                   (transfer.newTeamId?.toLowerCase().contains(q) ?? false);
          }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.push('/admin_panel'),
        ),
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search transfers...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: StreamBuilder<List<Transfer>>(
  stream: widget.transferService.streamTransfers(),
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
          'No transfers found',
          style: AppTextStyles.subheadingStyle,
        ),
      );
    }

    final transfers = snapshot.data!;
    _filteredTransfers =
        _filterTransfers(transfers, _searchController.text);

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _filteredTransfers.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 3.0),
          child: PlayerTransferCard(transfer: _filteredTransfers[index]),
        );
      },
    );
  },
),

      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create_transfer'),
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
