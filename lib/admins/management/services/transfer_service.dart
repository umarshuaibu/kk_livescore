import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transfer_model.dart';

class TransferService {
  final CollectionReference _transferCollection =
      FirebaseFirestore.instance.collection('transfers');

  /// Add a new transfer record (always enforces timestamp consistency)
  Future<void> addTransfer(Transfer transfer) async {
    try {
      final data = transfer.toMap();

      // Ensure timestamp is always set (fallback to server time if missing)
      data['timestamp'] = data['timestamp'] ?? FieldValue.serverTimestamp();

      await _transferCollection.add(data);
    } catch (e) {
      throw Exception('Failed to add transfer: $e');
    }
  }

  /// Fetch all transfers
  Future<List<Transfer>> fetchTransfers() async {
    try {
      final snapshot = await _transferCollection
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs
          .map((doc) =>
              Transfer.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transfers: $e');
    }
  }

  /// Stream transfers in real-time (useful for UI)
  Stream<List<Transfer>> streamTransfers() {
    return _transferCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                Transfer.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Fetch transfers for a specific player
  Future<List<Transfer>> fetchTransfersByPlayer(String playerId) async {
    try {
      final snapshot = await _transferCollection
          .where('playerId', isEqualTo: playerId)
          .orderBy('timestamp', descending: true) // keep it consistent
          .get();
      return snapshot.docs
          .map((doc) =>
              Transfer.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch player transfers: $e');
    }
  }

  /// Delete a transfer record
  Future<void> deleteTransfer(String transferId) async {
    try {
      await _transferCollection.doc(transferId).delete();
    } catch (e) {
      throw Exception('Failed to delete transfer: $e');
    }
  }
}
