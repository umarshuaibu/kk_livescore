import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String id;
  final String teamAId;
  final String teamBId;
  final int scoreA;
  final int scoreB;
  final String status;
  final Map<String, dynamic>? standingsSnapshot; // e.g. {'scoreA':1,'scoreB':0}

  MatchModel({
    required this.id,
    required this.teamAId,
    required this.teamBId,
    required this.scoreA,
    required this.scoreB,
    required this.status,
    this.standingsSnapshot,
  });

  factory MatchModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MatchModel(
      id: doc.id,
      teamAId: (d['teamAId'] ?? '').toString(),
      teamBId: (d['teamBId'] ?? '').toString(),
      scoreA: (d['scoreA'] ?? 0) is int ? d['scoreA'] : int.parse((d['scoreA'] ?? '0').toString()),
      scoreB: (d['scoreB'] ?? 0) is int ? d['scoreB'] : int.parse((d['scoreB'] ?? '0').toString()),
      status: (d['status'] ?? '').toString(),
      standingsSnapshot: d['standingsSnapshot'] != null ? Map<String, dynamic>.from(d['standingsSnapshot']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'teamAId': teamAId,
        'teamBId': teamBId,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'status': status,
        'standingsSnapshot': standingsSnapshot,
      };
}