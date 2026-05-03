// lib/core/services/dashboard_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetches the total number of users using the cost-efficient count() query
  Future<int> getTotalUsers() async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore.collection('users').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print("Error fetching user count: $e");
      return 0; 
    }
  }
}