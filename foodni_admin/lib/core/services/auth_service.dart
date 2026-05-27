import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> loginAdmin(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();


      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data['role'] == 'admin') {
          return null; 
        }
      }

      await _auth.signOut();
      //return 'Access Denied: You do not have admin privileges.';

    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Authentication failed';
    } catch (e) {
      await _auth.signOut();
      return 'Access Denied: You do not have admin privileges.';
    }
    return null;
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to send password reset email.';
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}