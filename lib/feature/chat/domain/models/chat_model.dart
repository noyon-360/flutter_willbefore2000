import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userPhoto;
  final String status; // "open" | "closed"
  final String? topic;
  final String? productId;
  final String? productTitle;
  final String? productImage;
  final double? productPrice;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool unreadForAdmin;
  final bool unreadForUser;
  final double? rating;
  final String? ratingComment;
  final DateTime? ratedAt;
  final DateTime? createdAt;
  final DateTime? closedAt;

  const ChatModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userPhoto,
    this.status = 'open',
    this.topic,
    this.productId,
    this.productTitle,
    this.productImage,
    this.productPrice,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadForAdmin = false,
    this.unreadForUser = false,
    this.rating,
    this.ratingComment,
    this.ratedAt,
    this.createdAt,
    this.closedAt,
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get hasProduct => productId != null && productId!.isNotEmpty;

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatModel(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString().isNotEmpty == true
          ? data['userName']?.toString()
          : null,
      userPhoto: data['userPhoto']?.toString().isNotEmpty == true
          ? data['userPhoto']?.toString()
          : null,
      status: data['status']?.toString() ?? 'open',
      topic: data['topic']?.toString().isNotEmpty == true
          ? data['topic']?.toString()
          : null,
      productId: data['productId']?.toString().isNotEmpty == true
          ? data['productId']?.toString()
          : null,
      productTitle: data['productTitle']?.toString().isNotEmpty == true
          ? data['productTitle']?.toString()
          : null,
      productImage: data['productImage']?.toString().isNotEmpty == true
          ? data['productImage']?.toString()
          : null,
      productPrice: (data['productPrice'] as num?)?.toDouble(),
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      unreadForAdmin: data['unreadForAdmin'] ?? false,
      unreadForUser: data['unreadForUser'] ?? false,
      rating: (data['rating'] as num?)?.toDouble(),
      ratingComment: data['ratingComment']?.toString().isNotEmpty == true
          ? data['ratingComment']?.toString()
          : null,
      ratedAt: data['ratedAt'] != null
          ? (data['ratedAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      closedAt: data['closedAt'] != null
          ? (data['closedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'status': status,
      'topic': topic,
      'productId': productId,
      'productTitle': productTitle,
      'productImage': productImage,
      'productPrice': productPrice,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : FieldValue.serverTimestamp(),
      'unreadForAdmin': unreadForAdmin,
      'unreadForUser': unreadForUser,
      'rating': rating,
      'ratingComment': ratingComment,
      'ratedAt': ratedAt != null ? Timestamp.fromDate(ratedAt!) : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
    };
  }

  ChatModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhoto,
    String? status,
    String? topic,
    String? productId,
    String? productTitle,
    String? productImage,
    double? productPrice,
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? unreadForAdmin,
    bool? unreadForUser,
    double? rating,
    String? ratingComment,
    DateTime? ratedAt,
    DateTime? createdAt,
    DateTime? closedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      status: status ?? this.status,
      topic: topic ?? this.topic,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadForAdmin: unreadForAdmin ?? this.unreadForAdmin,
      unreadForUser: unreadForUser ?? this.unreadForUser,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      ratedAt: ratedAt ?? this.ratedAt,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
