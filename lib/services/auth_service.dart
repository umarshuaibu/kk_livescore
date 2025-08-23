import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Initialize deep link handling
  Future<void> initDeepLinks() async {
    // Handle initial link (app opened from terminated state)
    final Uri? initialLink = await _appLinks.getInitialAppLink();
    if (initialLink != null) {
      await _handleSignInLink(initialLink.toString());
    }

    // Handle links when app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) async {
        if (uri != null) {
          await _handleSignInLink(uri.toString());
        }
      },
      onError: (err) {
        throw Exception('Error handling deep link: $err');
      },
    );
  }

  // Handle the sign-in link
  Future<void> _handleSignInLink(String link) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('signInEmail') ?? '';
      if (email.isEmpty) {
        throw Exception('No email found for sign-in');
      }
      final credential = await verifyEmailLink(email, link);
      if (credential != null) {
        // Clear stored email after successful sign-in
        await prefs.remove('signInEmail');
      } else {
        throw Exception('Invalid sign-in link: $link');
      }
    } catch (e) {
      throw Exception('Error handling sign-in link: $e');
    }
  }

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
          url: 'https://umarshuaibu.github.io/mylivescore-redirect/signin',
          handleCodeInApp: true,
          iOSBundleId: 'com.yourapp.ios',
          androidPackageName: 'com.datalinx.kklivescore',
          androidInstallApp: true,
          androidMinimumVersion: '12',
        ),
      );
      // Store the email for later use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('signInEmail', email);
    } on FirebaseAuthException catch (e) {
      throw Exception('Failed to send sign-in link: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
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

  // Sign in with email & password
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

  // Clean up deep link subscription
  void dispose() {
    _linkSubscription?.cancel();
  }
}