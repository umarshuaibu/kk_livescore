import 'package:flutter/material.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../models/coach_model.dart';
import 'package:go_router/go_router.dart';
import '../services/coach_service.dart';
import '../reusables/coach_info_card.dart';
import 'dart:async'; // Added for Timer
import '../reusables/custom_progress_indicator.dart'; // Added import for CustomProgressIndicator

class CoachListScreen extends StatefulWidget {
  final CoachService coachService = CoachService();

  CoachListScreen({super.key});

  @override
  State<CoachListScreen> createState() => _CoachListScreenState();
}

class _CoachListScreenState extends State<CoachListScreen> {
  late TextEditingController _searchController;
  List<Coach> _allCoaches = []; // Store full dataset
  List<Coach> _filteredCoaches = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadInitialCoaches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // Cancel any pending debounce
    super.dispose();
  }

  // Load initial coaches from stream and keep _allCoaches updated
  void _loadInitialCoaches() {
    widget.coachService.streamCoaches().listen((coaches) {
      if (mounted) {
        setState(() {
          _allCoaches = coaches; // Update full dataset
          _filteredCoaches = _allCoaches; // Initial display is full list
        });
      }
    });
  }

  // Search coaches by name dynamically
  void _searchCoaches(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final lowerQuery = query.toLowerCase();
      if (mounted) {
        setState(() {
          if (lowerQuery.isEmpty) {
            _filteredCoaches = List.from(_allCoaches); // Reset to full list
          } else {
            _filteredCoaches = _allCoaches.where((coach) {
              return coach.name.toLowerCase().contains(lowerQuery);
            }).toList();
          }
        });
      }
    });
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
            hintText: 'Search coaches...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.whiteColor),
          ),
          style: const TextStyle(color: AppColors.whiteColor),
          onChanged: _searchCoaches,
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: Stack(
        children: [
          // Main content (always visible)
          _allCoaches.isEmpty && _searchController.text.isNotEmpty
              ? const Center(child: Text('No coaches found', style: TextStyle(color: AppColors.whiteColor)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _filteredCoaches.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: CoachInfoCard(coach: _filteredCoaches[index]),
                    );
                  },
                ),
          // Loading overlay with CustomProgressIndicator
          if (_allCoaches.isEmpty)
            Container(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
              child: Center(child: CustomProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create_coach'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}