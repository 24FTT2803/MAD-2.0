import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hobbee_app/models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<AppUser?> getCurrentUserData() async {
    if (currentUser == null) return null;
    final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
    if (doc.exists) {
      return AppUser.fromJson(doc.data()!);
    }
    return null;
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<void> registerWithEmailAndPassword(
    String username,
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Determine role based on username
      String role = 'user';
      if (username.toLowerCase() == 'admin') {
        role = 'admin';
      } else if (username.toLowerCase() == 'superadmin') {
        role = 'superadmin';
      }

      final appUser = AppUser(
        id: credential.user!.uid,
        username: username,
        email: email,
        role: role,
        hobbies: [],
        profileImage: null,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(credential.user!.uid).set(
        appUser.toJson(),
      );
      
      print('✅ User registered and document created: $username');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'Email already in use.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}