import 'package:flutter/material.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../models/coach_model.dart';
import '../services/coach_service.dart';
import '../reusables/coach_info_card.dart';

class CoachListScreen extends StatelessWidget {
  final CoachService coachService = CoachService();

  CoachListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Coach>>(
      stream: coachService.streamCoaches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: AppTextStyles.subheadingStyle));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No coaches found', style: AppTextStyles.subheadingStyle));
        }

        final coaches = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: coaches.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: CoachInfoCard(coach: coaches[index]),
            );
          },
        );
      },
    );
  }
}