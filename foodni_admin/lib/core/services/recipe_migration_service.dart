import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeMigrationService {
  /// Sets `status: 'pending'` on every recipe document that currently has no
  /// `status` field.  Uses a [WriteBatch] to minimise round-trips.
  static Future<void> migrateUnstatuedRecipes() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('recipes').get();

    final docsToMigrate = snapshot.docs
        .where((doc) => (doc.data())['status'] == null)
        .toList();

    if (docsToMigrate.isEmpty) return;

    // Firestore batches are capped at 500 writes; chunk if necessary.
    const batchSize = 500;
    for (var i = 0; i < docsToMigrate.length; i += batchSize) {
      final chunk = docsToMigrate.skip(i).take(batchSize);
      final batch = firestore.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {'status': 'pending'});
      }
      await batch.commit();
    }
  }
}
