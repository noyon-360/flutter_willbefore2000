import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:smilestreatsapp/core/common/widgets/login_required_dialog.dart';
import 'package:smilestreatsapp/core/common/widgets/star_rating.dart';
import 'package:smilestreatsapp/core/constants/app_colors.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/product_review.dart';
import '../providers/review_provider.dart';

class ReviewSection extends ConsumerStatefulWidget {
  final String productId;

  const ReviewSection({super.key, required this.productId});

  @override
  ConsumerState<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends ConsumerState<ReviewSection> {
  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewProvider(widget.productId));
    final authState = ref.watch(authProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reviews (${reviewState.reviews.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textAppBlack,
              ),
            ),
            TextButton(
              onPressed: reviewState.isLoading
                  ? null
                  : () => _openReviewForm(
                        context,
                        authState.isAuthenticated,
                        reviewState.myReview,
                      ),
              child: Text(
                reviewState.myReview != null ? 'Edit your review' : 'Write a review',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (reviewState.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: AppColors.primaryLaurel),
            ),
          )
        else if (reviewState.reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No reviews yet. Be the first to review this product!',
              style: TextStyle(color: AppColors.textSecondaryColor),
            ),
          )
        else
          ...reviewState.reviews.map((review) => _ReviewTile(review: review)),
      ],
    );
  }

  void _openReviewForm(
    BuildContext context,
    bool isAuthenticated,
    ProductReview? existing,
  ) {
    if (!isAuthenticated) {
      LoginRequiredDialog.show(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _ReviewFormSheet(
        productId: widget.productId,
        existing: existing,
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ProductReview review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.userDisplayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textAppBlack,
                ),
              ),
              const SizedBox(width: 8),
              StarRatingDisplay(rating: review.rating.toDouble(), size: 14),
              const Spacer(),
              Text(
                DateFormat('dd MMM yyyy').format(review.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryColor,
                ),
              ),
            ],
          ),
          if (review.reviewText?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              review.reviewText!,
              style: TextStyle(color: AppColors.textSecondaryColor),
            ),
          ],
          const Divider(height: 20),
        ],
      ),
    );
  }
}

class _ReviewFormSheet extends ConsumerStatefulWidget {
  final String productId;
  final ProductReview? existing;

  const _ReviewFormSheet({required this.productId, this.existing});

  @override
  ConsumerState<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends ConsumerState<_ReviewFormSheet> {
  late int _rating = widget.existing?.rating ?? 5;
  late final TextEditingController _textController =
      TextEditingController(text: widget.existing?.reviewText ?? '');

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewProvider(widget.productId));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null ? 'Edit your review' : 'Write a review',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textAppBlack,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: StarRatingInput(
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Share your thoughts about this product (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: reviewState.isSubmitting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final success = await ref
                          .read(reviewProvider(widget.productId).notifier)
                          .submitOrUpdateReview(
                            rating: _rating,
                            reviewText: _textController.text.trim().isEmpty
                                ? null
                                : _textController.text.trim(),
                          );
                      if (!mounted) return;
                      if (success) {
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Review submitted!')),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Failed to submit review'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLaurel,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: reviewState.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
