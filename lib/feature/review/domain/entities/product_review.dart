class ProductReview {
  final String id;
  final String productId;
  final String userId;
  final String userDisplayName;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userDisplayName,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    required this.updatedAt,
  });

  ProductReview copyWith({
    String? id,
    String? productId,
    String? userId,
    String? userDisplayName,
    int? rating,
    String? reviewText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductReview(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductReview &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
