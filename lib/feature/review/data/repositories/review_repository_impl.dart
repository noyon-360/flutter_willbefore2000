import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product_review.dart';
import '../../domain/repositories/review_repository.dart';
import '../sources/review_remote_data_source.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewRemoteDataSource remoteDataSource;

  ReviewRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ProductReview>> getReviewsForProduct(String productId) =>
      remoteDataSource.getReviewsForProduct(productId);

  @override
  Future<ProductReview?> getMyReviewForProduct(String productId) =>
      remoteDataSource.getMyReviewForProduct(productId);

  @override
  Future<void> submitReview({
    required String productId,
    required int rating,
    String? reviewText,
  }) =>
      remoteDataSource.submitReview(
        productId: productId,
        rating: rating,
        reviewText: reviewText,
      );

  @override
  Future<void> updateReview({
    required String productId,
    required int rating,
    String? reviewText,
  }) =>
      remoteDataSource.updateReview(
        productId: productId,
        rating: rating,
        reviewText: reviewText,
      );

  @override
  Future<void> deleteReview(String productId) =>
      remoteDataSource.deleteReview(productId);

  @override
  Future<void> recordProductView(String productId) =>
      remoteDataSource.recordProductView(productId);
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final remoteDataSource = ReviewRemoteDataSource(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
  return ReviewRepositoryImpl(remoteDataSource);
});
