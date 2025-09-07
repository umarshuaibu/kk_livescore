import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/coach_model.dart';

class CoachService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'coaches';

  // Add a new coach with auto-generated ID
  Future<void> addCoach(Coach coach) async {
    try {
      final docRef = _firestore.collection(_collection).doc(); // Auto-generates ID
      final newCoach = Coach(
        id: docRef.id,
        name: coach.name,
        teamId: coach.teamId,
        teamName: coach.teamName,
        photoUrl: coach.photoUrl,
        dateOfBirth: coach.dateOfBirth, // ✅ include DOB
      );
      await docRef.set(newCoach.toMap());
    } catch (e) {
      throw Exception('Failed to add coach: $e');
    }
  }



  // Fetch all coaches with optional limit
  Future<List<Coach>> fetchCoaches({int limit = 0}) async {
    try {
      QuerySnapshot snapshot = limit > 0
          ? await _firestore.collection(_collection).limit(limit).get()
          : await _firestore.collection(_collection).get();

      return snapshot.docs
          .map((doc) => Coach.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch coaches: $e');
    }
  }

  // Delete a coach by ID
  Future<void> deleteCoach(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete coach: $e');
    }
  }

  // Edit a coach by ID
  Future<void> editCoach(String id, Coach updatedCoach) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(updatedCoach.toMap());
    } catch (e) {
      throw Exception('Failed to edit coach: $e');
    }
  }

  // Stream coaches
  Stream<List<Coach>> streamCoaches() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Coach.fromMap(doc.data()))
            .toList());
  }

  // Filter coaches by name (case-insensitive prefix search)
  Future<List<Coach>> filterCoachesByName(String name) async {
    try {
      final query = name.toLowerCase();
      final snapshot = await _firestore
          .collection(_collection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) => Coach.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to filter coaches: $e');
    }
  }
}