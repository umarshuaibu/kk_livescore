import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'constants.dart'; // Adjust import path
import '../models/team_model.dart';
import '../services/coach_service.dart';

class TeamInfoCard extends StatefulWidget {
  final Team team;

  const TeamInfoCard({super.key, required this.team});

  @override
  State<TeamInfoCard> createState() => _TeamInfoCardState();
}

class _TeamInfoCardState extends State<TeamInfoCard> {
  String? _coachName;

  @override
  void initState() {
    super.initState();
    _loadCoachName();
  }

  Future<void> _loadCoachName() async {
    if (widget.team.coachId != null && widget.team.coachId!.isNotEmpty) {
      final coach = await CoachService().fetchCoachById(widget.team.coachId!);
      if (mounted) {
        setState(() {
          _coachName = coach?.name ?? "Unknown";
        });
      }
    } else {
      setState(() {
        _coachName = "Not Assigned";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.0)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
           /// COLUMN 1 - Team Logo (Circular Avatar)
Expanded(
  flex: 2,
  child: widget.team.logoUrl != null && widget.team.logoUrl!.isNotEmpty
      ? CircleAvatar(
          radius: 22, // makes it circular
          backgroundImage: NetworkImage(widget.team.logoUrl!),
          onBackgroundImageError: (_, __) {
            // fallback icon if image fails
          },
          // ignore: deprecated_member_use
          backgroundColor: AppColors.primaryColor.withOpacity(0.1),
        )
      : const CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryColor,
          child: Icon(Icons.shield, color: AppColors.whiteColor, size: 22),
        ),
),

            /// COLUMN 2 - Team Info
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Row 1: Team Name
                  Text(
                    widget.team.name,
                    style: AppTextStyles.headingStyle.copyWith(fontSize: 14), // smaller
                  ),
                  const SizedBox(height: 6),

                  /// Row 2: Abbr + Coach
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          "Coach: ${_coachName ?? 'Loading...'}",
                          style: AppTextStyles.subheadingStyle.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
                    onPressed: () =>context.push("/edit_team"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2), // tighter padding
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
