import '../entities/product_review.dart';

abstract class ReviewRepository {
  /// All approved reviews for a product, newest first.
  Future<List<ProductReview>> getReviewsForProduct(String productId);

  /// The current user's own review for a product, or null if they haven't
  /// reviewed it yet. Used to switch between "write a review" and "edit
  /// your review" in the UI.
  Future<ProductReview?> getMyReviewForProduct(String productId);

  /// Creates the current user's review for a product. Fails if they've
  /// already reviewed it (use [updateReview] instead).
  Future<void> submitReview({
    required String productId,
    required int rating,
    String? reviewText,
  });

  /// Edits the current user's existing review for a product.
  Future<void> updateReview({
    required String productId,
    required int rating,
    String? reviewText,
  });

  /// Deletes the current user's review for a product.
  Future<void> deleteReview(String productId);

  /// Records that the current user has viewed a product, once per user.
  /// Safe to call on every product-detail visit - a repeat view is a
  /// harmless no-op (rejected by Firestore rules, swallowed here).
  Future<void> recordProductView(String productId);
}
