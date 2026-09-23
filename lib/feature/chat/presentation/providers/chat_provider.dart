import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/faq_repository.dart';
import '../../domain/models/chat_message_model.dart';
import '../../domain/models/chat_model.dart';
import '../../domain/models/chat_product_ref.dart';

const String _chatsCollection = 'chats';
const String _messagesSubcollection = 'messages';

/// Stream of the current user's active support chat.
///
/// Prefers an "open" chat; falls back to the most recently created chat
/// (which may be closed) so a user can still see history, or null if the
/// user has never started a chat.
final currentChatProvider = StreamProvider.autoDispose<ChatModel?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection(_chatsCollection)
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return ChatModel.fromFirestore(snapshot.docs.first);
      });
});

/// Stream of messages for a given chat, ordered oldest -> newest.
final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) {
      if (chatId.isEmpty) return Stream.value(const []);

      return FirebaseFirestore.instance
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesSubcollection)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(ChatMessage.fromFirestore).toList(),
          );
    });

/// Convenience provider exposing the [AutoReplyService] implementation.
final autoReplyServiceProvider = Provider<AutoReplyService>((ref) {
  return const StaticAutoReplyService();
});

/// Provider for the [ChatService] class used to write to Firestore.
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection(_chatsCollection);

  /// Finds the current user's open chat, or creates a new one.
  Future<DocumentReference<Map<String, dynamic>>> _findOrCreateOpenChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Cannot start a chat: user is not logged in.');
    }

    final existing = await _chats
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.reference;
    }

    final chat = ChatModel(
      id: '',
      userId: user.uid,
      userName: user.displayName,
      userPhoto: user.photoURL,
      status: 'open',
      lastMessage: '',
      createdAt: DateTime.now(),
    );

    final docRef = await _chats.add(chat.toFirestore());
    return docRef;
  }

  /// Sends a plain text message from the user, creating a chat if needed.
  ///
  /// If [product] is given, the message is tagged as being about that
  /// product (rendered with a small product chip) and the chat's
  /// product-context fields are updated to match. Returns the chat id.
  Future<String> sendMessage(String text, {ChatProductRef? product}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Cannot send a message: user is not logged in.');
    }

    final chatRef = await _findOrCreateOpenChat();

    final message = ChatMessage(
      id: '',
      senderId: user.uid,
      senderRole: 'user',
      text: trimmed,
      type: product != null ? 'product_card' : 'text',
      productId: product?.id,
      productTitle: product?.title,
      productImage: product?.image,
      productPrice: product?.price,
    );

    await chatRef.collection(_messagesSubcollection).add(message.toFirestore());

    final chatUpdate = <String, dynamic>{
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadForAdmin': true,
    };
    if (product != null) {
      chatUpdate['productId'] = product.id;
      chatUpdate['productTitle'] = product.title;
      chatUpdate['productImage'] = product.image;
      chatUpdate['productPrice'] = product.price;
    }
    await chatRef.update(chatUpdate);

    return chatRef.id;
  }

  /// Sends a quick-reply FAQ question and its canned bot answer as a batch.
  Future<void> sendQuickReply(FaqEntry entry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Cannot send a message: user is not logged in.');
    }

    final chatRef = await _findOrCreateOpenChat();
    final batch = _firestore.batch();

    final questionMessage = ChatMessage(
      id: '',
      senderId: user.uid,
      senderRole: 'user',
      text: entry.question,
      type: 'text',
    );
    final questionRef = chatRef.collection(_messagesSubcollection).doc();
    batch.set(questionRef, questionMessage.toFirestore());

    final answerMessage = ChatMessage(
      id: '',
      senderId: 'bot',
      senderRole: 'bot',
      text: entry.answer,
      type: 'auto_reply',
    );
    final answerRef = chatRef.collection(_messagesSubcollection).doc();
    batch.set(answerRef, answerMessage.toFirestore());

    batch.update(chatRef, {
      'topic': entry.id,
      'lastMessage': entry.answer,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadForAdmin': true,
    });

    await batch.commit();
  }

  /// Rates a closed chat's support experience. Rating is given by the
  /// customer only — there is no admin-side equivalent.
  Future<void> submitRating(String chatId, int rating, String? comment) async {
    await _chats.doc(chatId).update({
      'rating': rating,
      'ratingComment': comment,
      'ratedAt': FieldValue.serverTimestamp(),
    });
  }
}
