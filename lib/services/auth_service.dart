import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if email is whitelisted
  Future<bool> isEmailWhitelisted(String email) async {
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      throw Exception('Invalid email format');
    }
    try {
      final query = await _firestore
          .collection('whitelist')
          .where('email', isEqualTo: email)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to verify email whitelist: $e');
    }
  }

  // Send passwordless sign-in link to email
  Future<void> sendSignInLinkToEmail(String email) async {
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      throw Exception('Invalid email format');
    }
    try {
      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://kk-livescore.firebaseapp.com/finishSignUp',
          handleCodeInApp: true,
          iOSBundleId: 'com.yourapp.ios',
          androidPackageName: 'com.kk-livescore.android',
          androidInstallApp: true,
          androidMinimumVersion: '12',
        ),
      );
    } catch (e) {
      throw Exception('Failed to send sign-in link: $e');
    }
  }

  // Verify email link and sign in
  Future<UserCredential?> verifyEmailLink(String email, String emailLink) async {
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      throw Exception('Invalid email format');
    }
    if (emailLink.isEmpty) {
      throw Exception('Invalid email link');
    }
    try {
      if (_auth.isSignInWithEmailLink(emailLink)) {
        final credential = await _auth.signInWithEmailLink(
          email: email,
          emailLink: emailLink,
        );
        return credential;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to verify email link: $e');
    }
  }

  // Save user data to Firestore
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }
      await _firestore.collection('users').doc(user.uid).set({
        ...userData,
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  // 🔹 New method: sign in with email & password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
}
