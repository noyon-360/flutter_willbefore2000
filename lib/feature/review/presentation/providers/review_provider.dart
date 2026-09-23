import 'package:flutter_riverpod/legacy.dart';

import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/repositories/review_repository.dart';

class ReviewState {
  final List<ProductReview> reviews;
  final ProductReview? myReview;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  const ReviewState({
    this.reviews = const [],
    this.myReview,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  ReviewState copyWith({
    List<ProductReview>? reviews,
    ProductReview? myReview,
    bool clearMyReview = false,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReviewState(
      reviews: reviews ?? this.reviews,
      myReview: clearMyReview ? null : (myReview ?? this.myReview),
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ReviewNotifier extends StateNotifier<ReviewState> {
  final ReviewRepository _repository;
  final String productId;

  ReviewNotifier(this._repository, this.productId)
      : super(const ReviewState()) {
    loadReviews();
  }

  Future<void> loadReviews() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repository.getReviewsForProduct(productId),
        _repository.getMyReviewForProduct(productId),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        reviews: results[0] as List<ProductReview>,
        myReview: results[1] as ProductReview?,
        clearMyReview: results[1] == null,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> submitOrUpdateReview({
    required int rating,
    String? reviewText,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      if (state.myReview != null) {
        await _repository.updateReview(
          productId: productId,
          rating: rating,
          reviewText: reviewText,
        );
      } else {
        await _repository.submitReview(
          productId: productId,
          rating: rating,
          reviewText: reviewText,
        );
      }
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false);
      await loadReviews();
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteMyReview() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.deleteReview(productId);
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false);
      await loadReviews();
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}

final reviewProvider = StateNotifierProvider.autoDispose
    .family<ReviewNotifier, ReviewState, String>((ref, productId) {
  final repository = ref.watch(reviewRepositoryProvider);
  return ReviewNotifier(repository, productId);
});
