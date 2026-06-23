import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/user_model.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── User stats ────────────────────────────────────────────────────────────

  Future<int> getTotalUsers() async {
    try {
      final snapshot = await _firestore.collection('users').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Stream<List<UserModel>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user document: $e');
    }
  }

  // ── Food item / scan stats ────────────────────────────────────────────────

  /// Total food items saved across all users (manual + AI scan).
  Future<int> getTotalFoodItems() async {
    try {
      final snapshot = await _firestore.collection('foodItems').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Total AI food scans (items saved with source == 'ai_scan').
  Future<int> getTotalFoodScans() async {
    try {
      final snapshot = await _firestore
          .collection('foodItems')
          .where('source', isEqualTo: 'ai_scan')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ── Recipe stats ──────────────────────────────────────────────────────────

  /// Total community-uploaded recipes (any status).
  /// Counts docs that have a 'status' field (set by the upload screen).
  Future<int> getTotalCommunityRecipes() async {
    try {
      // Use status-based count: pending + approved + rejected = total uploads
      final results = await Future.wait([
        _firestore.collection('recipes').where('status', isEqualTo: 'pending').count().get(),
        _firestore.collection('recipes').where('status', isEqualTo: 'approved').count().get(),
        _firestore.collection('recipes').where('status', isEqualTo: 'rejected').count().get(),
      ]);
      return (results[0].count ?? 0) +
          (results[1].count ?? 0) +
          (results[2].count ?? 0);
    } catch (e) {
      return 0;
    }
  }

  /// Total seeded / FoodNi-curated recipes (docs that have no 'status' field).
  /// Computed as: total recipes collection count − community recipes count.
  Future<int> getTotalSeededRecipes() async {
    try {
      final results = await Future.wait<int>([
        _firestore.collection('recipes').count().get().then((s) => s.count ?? 0),
        getTotalCommunityRecipes(),
      ]);
      final total = results[0];
      final community = results[1];
      final diff = total - community;
      return diff < 0 ? 0 : diff;
    } catch (e) {
      return 0;
    }
  }

  /// Community recipes waiting for review.
  Future<int> getPendingRecipesCount() async {
    try {
      final snapshot = await _firestore
          .collection('recipes')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Community recipes that have been approved.
  Future<int> getApprovedRecipesCount() async {
    try {
      final snapshot = await _firestore
          .collection('recipes')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Stream of the 5 most recent pending recipes for the dashboard preview.
  /// Sorted client-side to avoid requiring a composite Firestore index.
  Stream<QuerySnapshot> getRecentPendingRecipesStream() {
    return _firestore
        .collection('recipes')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // ── Aggregate helper ──────────────────────────────────────────────────────

  /// Fetches all dashboard stat values in parallel.
  Future<DashboardStats> getAllStats() async {
    final results = await Future.wait([
      getTotalUsers(),
      getTotalFoodItems(),
      getTotalFoodScans(),
      getTotalCommunityRecipes(),
      getPendingRecipesCount(),
      getApprovedRecipesCount(),
      getTotalSeededRecipes(),
    ]);
    return DashboardStats(
      totalUsers: results[0],
      totalFoodItems: results[1],
      totalFoodScans: results[2],
      totalRecipes: results[3],
      pendingRecipes: results[4],
      approvedRecipes: results[5],
      seededRecipes: results[6],
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.totalUsers,
    required this.totalFoodItems,
    required this.totalFoodScans,
    required this.totalRecipes,
    required this.pendingRecipes,
    required this.approvedRecipes,
    required this.seededRecipes,
  });

  final int totalUsers;
  final int totalFoodItems;
  final int totalFoodScans;
  final int totalRecipes;
  final int pendingRecipes;
  final int approvedRecipes;
  /// FoodNi-curated (seeded) recipes with no status field.
  final int seededRecipes;
}
