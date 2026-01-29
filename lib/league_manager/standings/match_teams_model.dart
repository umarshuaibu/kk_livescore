import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String logoUrl;

  TeamModel({
    required this.id,
    required this.name,
    required this.logoUrl,
  });


  factory TeamModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TeamModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      logoUrl: (data['logoUrl'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
      };

  factory TeamModel.fromJson(Map<String, dynamic> json) => TeamModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        logoUrl: json['logoUrl'] ?? '',
      ); 
}