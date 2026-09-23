import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product_review.dart';

class ProductReviewModel extends ProductReview {
  const ProductReviewModel({
    required super.id,
    required super.productId,
    required super.userId,
    required super.userDisplayName,
    required super.rating,
    super.reviewText,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductReviewModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0) as int,
      reviewText: data['reviewText'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
