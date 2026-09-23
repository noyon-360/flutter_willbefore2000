import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutx_core/flutx_core.dart';

import '../models/product_review_model.dart';

class ReviewRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ReviewRemoteDataSource(this._firestore, this._auth);

  String? get _userId => _auth.currentUser?.uid;

  String _reviewDocId(String productId) => '${_userId}_$productId';

  Future<List<ProductReviewModel>> getReviewsForProduct(
    String productId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('productReviews')
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ProductReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      DPrint.log('Error fetching reviews for $productId: $e');
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  Future<ProductReviewModel?> getMyReviewForProduct(String productId) async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final doc = await _firestore
          .collection('productReviews')
          .doc(_reviewDocId(productId))
          .get();
      if (!doc.exists) return null;
      return ProductReviewModel.fromFirestore(doc);
    } catch (e) {
      DPrint.log('Error fetching my review for $productId: $e');
      throw Exception('Failed to fetch your review: $e');
    }
  }

  Future<void> submitReview({
    required String productId,
    required int rating,
    String? reviewText,
  }) async {
    final userId = _userId;
    final displayName = _auth.currentUser?.displayName;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    final now = DateTime.now();
    final model = ProductReviewModel(
      id: _reviewDocId(productId),
      productId: productId,
      userId: userId,
      userDisplayName: (displayName?.isNotEmpty ?? false)
          ? displayName!
          : 'Anonymous',
      rating: rating,
      reviewText: reviewText,
      createdAt: now,
      updatedAt: now,
    );
    try {
      // A plain set() on a not-yet-existing doc is evaluated as a Firestore
      // rules "create" - if the user already reviewed this product, rules
      // reject it (their doc already exists), so this is inherently
      // one-review-per-user without needing a query-then-write round trip.
      await _firestore
          .collection('productReviews')
          .doc(model.id)
          .set(model.toFirestore());
    } catch (e) {
      DPrint.log('Error submitting review for $productId: $e');
      throw Exception('Failed to submit review: $e');
    }
  }

  Future<void> updateReview({
    required String productId,
    required int rating,
    String? reviewText,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    try {
      await _firestore
          .collection('productReviews')
          .doc(_reviewDocId(productId))
          .update({
        'rating': rating,
        'reviewText': reviewText,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      DPrint.log('Error updating review for $productId: $e');
      throw Exception('Failed to update review: $e');
    }
  }

  Future<void> deleteReview(String productId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    try {
      await _firestore
          .collection('productReviews')
          .doc(_reviewDocId(productId))
          .delete();
    } catch (e) {
      DPrint.log('Error deleting review for $productId: $e');
      throw Exception('Failed to delete review: $e');
    }
  }

  Future<void> recordProductView(String productId) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('viewEvents')
          .doc(userId)
          .set({'firstViewedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      // Expected/harmless: Firestore rules reject this write outright if
      // the user has already viewed this product (the marker doc already
      // exists), which is exactly how "count a view once per user" is
      // enforced - not a real error.
      DPrint.log('recordProductView no-op for $productId: $e');
    }
  }
}
