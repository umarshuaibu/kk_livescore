import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TeamMini extends StatelessWidget {
  final String teamId;

  const TeamMini({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final teamRef =
        FirebaseFirestore.instance.collection('teams').doc(teamId);

    return FutureBuilder<DocumentSnapshot>(
      future: teamRef.get(),
      builder: (context, snapshot) {
        String abbr = '---';
        String logoUrl = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          abbr = data['abbr'] ?? abbr;
          logoUrl = data['logoUrl'] ?? '';
        }

        return Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: logoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(logoUrl)
                  : null,
              child: logoUrl.isEmpty
                  ? const Icon(Icons.shield, size: 20)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              abbr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}
