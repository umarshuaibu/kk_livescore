import 'package:cloud_firestore/cloud_firestore.dart';

/// =======================
/// TRANSFER FEATURE VIEWS
/// =======================
/// Controls which Transfer screen is visible inside dashboard body
enum TransferView {
  list,
  create,
  details,
}

/// =======================
/// TRANSFER TYPES
/// =======================
/// Strongly-typed alternative to raw strings
enum TransferType {
  transfer,
  release,
  delete,
}

extension TransferTypeX on TransferType {
  String get value {
    switch (this) {
      case TransferType.transfer:
        return "Transfer";
      case TransferType.release:
        return "Release";
      case TransferType.delete:
        return "Delete";
    }
  }

  static TransferType fromString(String value) {
    switch (value) {
      case "Release":
        return TransferType.release;
      case "Delete":
        return TransferType.delete;
      default:
        return TransferType.transfer;
    }
  }
}

/// =======================
/// TRANSFER MODEL
/// =======================
class Transfer {
  final String id;
  final String playerId;
  final String oldTeamId;
  final String? newTeamId; // null if Release or Delete
  final String type;       // Stored as String for Firestore compatibility
  final DateTime timestamp;
  final String? initiatedBy; // optional (admin id)

  /// ✅ Computed alias for clarity
  DateTime get date => timestamp;

  /// ✅ Optional helper to access enum safely
  TransferType get transferType => TransferTypeX.fromString(type);

  Transfer({
    required this.id,
    required this.playerId,
    required this.oldTeamId,
    this.newTeamId,
    required this.type,
    required this.timestamp,
    this.initiatedBy,
  });

  /// ✅ Convert Firestore document -> Transfer object
  factory Transfer.fromMap(Map<String, dynamic> data, String documentId) {
    return Transfer(
      id: documentId,
      playerId: data['playerId'] ?? '',
      oldTeamId: data['oldTeamId'] ?? '',
      newTeamId: data['newTeamId'],
      type: data['type'] ?? 'Transfer',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      initiatedBy: data['initiatedBy'],
    );
  }

  /// ✅ Convert Transfer object -> Firestore map
  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'oldTeamId': oldTeamId,
      'newTeamId': newTeamId,
      'type': type,
      'timestamp': timestamp,
      'initiatedBy': initiatedBy,
    };
  }

  /// ✅ Factory helper when creating new transfers in UI
  factory Transfer.create({
    required String playerId,
    required String oldTeamId,
    String? newTeamId,
    required TransferType type,
    String? initiatedBy,
  }) {
    return Transfer(
      id: '',
      playerId: playerId,
      oldTeamId: oldTeamId,
      newTeamId: newTeamId,
      type: type.value,
      timestamp: DateTime.now(),
      initiatedBy: initiatedBy,
    );
  }
}
