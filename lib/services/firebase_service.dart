import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<Map<String, dynamic>>> getLeagues() async {
    final snapshot = await _firestore.collection('leagues').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> getTeams() async {
    final snapshot = await _firestore.collection('teams').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> getPlayers() async {
    final snapshot = await _firestore.collection('players').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> getCoaches() async {
    final snapshot = await _firestore.collection('coaches').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> getReferees() async {
    final snapshot = await _firestore.collection('referees').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> getTransfers() async {
    final snapshot = await _firestore.collection('transfers').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingSignups() async {
    final snapshot = await _firestore.collection('pending_signups').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> getLoginRequests() async {
    final snapshot = await _firestore.collection('login_requests').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<String> uploadImage(File image, String path) async {
    final decodedImage = img.decodeImage(await image.readAsBytes());
    if (decodedImage == null) {
      throw Exception('Invalid image file.');
    }
    if (decodedImage.width != 192 || decodedImage.height != 192) {
      throw Exception('Image must be 192x192 pixels.');
    }
    if (!image.path.toLowerCase().endsWith('.png')) {
      throw Exception('Image must be in PNG format.');
    }

    final ref = _storage.ref(path);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> createLeague({required String name, String? logoUrl}) async {
    await _firestore.collection('leagues').add({
      'name': name,
      'logoUrl': logoUrl,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateLeague(String id, {required String name, String? logoUrl}) async {
    await _firestore.collection('leagues').doc(id).update({
      'name': name,
      'logoUrl': logoUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteLeague(String id) async {
    await _firestore.collection('leagues').doc(id).delete();
  }

  Future<void> createTeam({required String name, required String leagueId, String? logoUrl}) async {
    await _firestore.collection('teams').add({
      'name': name,
      'leagueId': leagueId,
      'logoUrl': logoUrl,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateTeam(String id, {required String name, required String leagueId, String? logoUrl}) async {
    await _firestore.collection('teams').doc(id).update({
      'name': name,
      'leagueId': leagueId,
      'logoUrl': logoUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteTeam(String id) async {
    await _firestore.collection('teams').doc(id).delete();
  }

  Future<void> createPlayer({
    required String firstName,
    required String lastName,
    required int yearOfBirth,
    required String state,
    required String city,
    required String position,
    required int jerseyNo,
    String? photoUrl,
  }) async {
    await _firestore.collection('players').add({
      'firstName': firstName,
      'lastName': lastName,
      'yearOfBirth': yearOfBirth,
      'state': state,
      'city': city,
      'position': position,
      'jerseyNo': jerseyNo,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updatePlayer(String id, {
    required String firstName,
    required String lastName,
    required int yearOfBirth,
    required String state,
    required String city,
    required String position,
    required int jerseyNo,
    String? photoUrl,
  }) async {
    await _firestore.collection('players').doc(id).update({
      'firstName': firstName,
      'lastName': lastName,
      'yearOfBirth': yearOfBirth,
      'state': state,
      'city': city,
      'position': position,
      'jerseyNo': jerseyNo,
      'photoUrl': photoUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deletePlayer(String id) async {
    await _firestore.collection('players').doc(id).delete();
  }

  Future<void> createCoach({
    required String firstName,
    required String lastName,
    required int yearsOfExperience,
    String? photoUrl,
  }) async {
    await _firestore.collection('coaches').add({
      'firstName': firstName,
      'lastName': lastName,
      'yearsOfExperience': yearsOfExperience,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateCoach(String id, {
    required String firstName,
    required String lastName,
    required int yearsOfExperience,
    String? photoUrl,
  }) async {
    await _firestore.collection('coaches').doc(id).update({
      'firstName': firstName,
      'lastName': lastName,
      'yearsOfExperience': yearsOfExperience,
      'photoUrl': photoUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteCoach(String id) async {
    await _firestore.collection('coaches').doc(id).delete();
  }

  Future<void> createReferee({
    required String firstName,
    required String lastName,
    String? photoUrl,
  }) async {
    await _firestore.collection('referees').add({
      'firstName': firstName,
      'lastName': lastName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateReferee(String id, {
    required String firstName,
    required String lastName,
    String? photoUrl,
  }) async {
    await _firestore.collection('referees').doc(id).update({
      'firstName': firstName,
      'lastName': lastName,
      'photoUrl': photoUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteReferee(String id) async {
    await _firestore.collection('referees').doc(id).delete();
  }

  Future<void> createTransfer({
    required String playerId,
    required String fromTeamId,
    required String toTeamId,
    required DateTime transferDate,
  }) async {
    await _firestore.collection('transfers').add({
      'playerId': playerId,
      'fromTeamId': fromTeamId,
      'toTeamId': toTeamId,
      'transferDate': Timestamp.fromDate(transferDate),
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateTransfer(String id, {
    required String playerId,
    required String fromTeamId,
    required String toTeamId,
    required DateTime transferDate,
  }) async {
    await _firestore.collection('transfers').doc(id).update({
      'playerId': playerId,
      'fromTeamId': fromTeamId,
      'toTeamId': toTeamId,
      'transferDate': Timestamp.fromDate(transferDate),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteTransfer(String id) async {
    await _firestore.collection('transfers').doc(id).delete();
  }

  Future<void> approveSignup(String signupId) async {
    final signupDoc = await _firestore.collection('pending_signups').doc(signupId).get();
    if (signupDoc.exists) {
      await _firestore.collection('users').doc(signupDoc.id).set({
        'email': signupDoc['email'],
        'phone': signupDoc['phone'],
        'role': signupDoc['role'],
        'approved': true,
        'league': signupDoc['league'],
        'firstName': signupDoc['firstName'],
        'lastName': signupDoc['lastName'],
      });
      await _firestore.collection('pending_signups').doc(signupId).delete();
    }
  }

  Future<void> rejectSignup(String signupId) async {
    await _firestore.collection('pending_signups').doc(signupId).delete();
  }

  Future<void> approveLoginRequest(String requestId) async {
    await _firestore.collection('login_requests').doc(requestId).update({'status': 'approved'});
  }

  Future<void> rejectLoginRequest(String requestId) async {
    await _firestore.collection('login_requests').doc(requestId).update({'status': 'rejected'});
  }
}