// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'constants.dart';
import '../models/coach_model.dart';
import 'package:go_router/go_router.dart';

class CoachInfoCard extends StatefulWidget {
  final Coach coach;

  const CoachInfoCard({super.key, required this.coach});

  @override
  State<CoachInfoCard> createState() => _CoachInfoCardState();
}

class _CoachInfoCardState extends State<CoachInfoCard> {
  int _calculateAge(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    _calculateAge(widget.coach.dateOfBirth);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.0)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
            /// COLUMN 1 - Coach Photo (Circular Avatar)
            Expanded(
              flex: 2,
              child: widget.coach.photoUrl != null &&
                      widget.coach.photoUrl!.isNotEmpty
                  ? CircleAvatar(
                      radius: 22,
                      backgroundImage: NetworkImage(widget.coach.photoUrl!),
                      backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                    )
                  : const CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryColor,
                      child: Icon(Icons.person,
                          color: AppColors.whiteColor, size: 22),
                    ),
            ),

            /// COLUMN 2 - Coach Info
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Row 1: Coach Name
                  Text(
                    widget.coach.name,
                    style:
                        AppTextStyles.headingStyle.copyWith(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  /// Row 2: Team + Age
                  Text(
                    "Team: ${widget.coach.teamName ?? 'N/A'}",
                    style: AppTextStyles.subheadingStyle
                        .copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            /// COLUMN 3 - Update Button
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => context.push("/edit_coach", extra: widget.coach),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 1, vertical: 2), // tighter padding
                    backgroundColor: AppColors.secondaryColor,
                    foregroundColor: AppColors.primaryColor,
                    textStyle: const TextStyle(fontSize: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text("Update"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
