import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String role;
  final String displayName;
  final String photoURL;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName = '',
    this.photoURL = '',
    this.lastLogin,
    this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      email: data['email'] ?? 'No Email',
      role: data['role'] ?? 'user',
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'] ?? '',
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
