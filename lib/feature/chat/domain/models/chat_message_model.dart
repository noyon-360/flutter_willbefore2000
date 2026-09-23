import 'package:cloud_firestore/cloud_firestore.dart';

/// senderRole: "user" | "admin" | "bot"
/// type: "text" | "auto_reply" | "product_card" | "system"
class ChatMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String text;
  final String type;
  final DateTime? createdAt;
  final bool read;
  final String? productId;
  final String? productTitle;
  final String? productImage;
  final double? productPrice;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.type = 'text',
    this.createdAt,
    this.read = false,
    this.productId,
    this.productTitle,
    this.productImage,
    this.productPrice,
  });

  bool get isFromUser => senderRole == 'user';
  bool get isFromAdmin => senderRole == 'admin';
  bool get isFromBot => senderRole == 'bot';
  bool get hasProduct => productId != null && productId!.isNotEmpty;

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId']?.toString() ?? '',
      senderRole: data['senderRole']?.toString() ?? 'user',
      text: data['text']?.toString() ?? '',
      type: data['type']?.toString() ?? 'text',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      read: data['read'] ?? false,
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      'type': type,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'read': read,
      'productId': productId,
      'productTitle': productTitle,
      'productImage': productImage,
      'productPrice': productPrice,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderRole,
    String? text,
    String? type,
    DateTime? createdAt,
    bool? read,
    String? productId,
    String? productTitle,
    String? productImage,
    double? productPrice,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
    );
  }
}
