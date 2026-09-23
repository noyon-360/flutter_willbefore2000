import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/faq_repository.dart';
import '../../domain/models/chat_product_ref.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_product_card.dart';
import '../widgets/chat_rating_prompt.dart';
import '../widgets/quick_reply_chips.dart';

class ChatScreen extends ConsumerStatefulWidget {
  /// A product carried over from the product detail screen. Shown as
  /// pending "replying to" context above the input until the user actually
  /// sends a message about it — nothing is posted just by opening the
  /// screen with this set.
  final ChatProductRef? initialProduct;

  const ChatScreen({super.key, this.initialProduct});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _ratingSubmitting = false;
  ChatProductRef? _pendingProduct;

  @override
  void initState() {
    super.initState();
    _pendingProduct = widget.initialProduct;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final product = _pendingProduct;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await ref
          .read(chatServiceProvider)
          .sendMessage(text, product: product);
      if (mounted) setState(() => _pendingProduct = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitRating(String chatId, int rating, String? comment) async {
    setState(() => _ratingSubmitting = true);
    try {
      await ref.read(chatServiceProvider).submitRating(chatId, rating, comment);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit rating: $e')));
      }
    } finally {
      if (mounted) setState(() => _ratingSubmitting = false);
    }
  }

  Future<void> _sendQuickReply(FaqEntry entry) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatServiceProvider).sendQuickReply(entry);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to chat with support')),
      );
    }

    final chatAsync = ref.watch(currentChatProvider);
    final suggestions = ref.read(autoReplyServiceProvider).getSuggestedQuestions();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Support Chat'),
            if (chatAsync.value?.isClosed == true)
              Text(
                'Chat ended',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textAppBlack,
        elevation: 0,
      ),
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (chat) {
          final chatId = chat?.id ?? '';
          final isClosed = chat?.isClosed == true;

          return Column(
            children: [
              if (chat != null && chat.hasProduct) ChatProductCard(chat: chat),
              Expanded(
                child: chatId.isEmpty
                    ? _buildEmptyState()
                    : _buildMessages(chatId),
              ),
              if (isClosed && chat!.rating == null)
                ChatRatingPrompt(
                  submitting: _ratingSubmitting,
                  onSubmit: (rating, comment) =>
                      _submitRating(chat.id, rating, comment),
                )
              else if (isClosed)
                _buildClosedBanner(),
              Consumer(
                builder: (context, ref, _) {
                  final messagesCount = chatId.isEmpty
                      ? 0
                      : ref
                            .watch(chatMessagesProvider(chatId))
                            .maybeWhen(
                              data: (messages) => messages.length,
                              orElse: () => 0,
                            );
                  final showSuggestions =
                      messagesCount < 3 && (chat == null || chat.isOpen);
                  if (!showSuggestions) return const SizedBox.shrink();
                  return QuickReplyChips(
                    entries: suggestions,
                    enabled: !_sending,
                    onSelected: _sendQuickReply,
                  );
                },
              ),
              if (_pendingProduct != null) _buildPendingProductPreview(),
              _buildInputBar(
                hintText: isClosed
                    ? 'Send a message to start a new conversation...'
                    : 'Type a message...',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Text(
        'This chat has ended.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildPendingProductPreview() {
    final product = _pendingProduct!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.image != null && product.image!.isNotEmpty
                ? Image.network(
                    product.image!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(width: 40, height: 40, color: Colors.grey[300]),
                  )
                : Container(width: 40, height: 40, color: Colors.grey[300]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying about',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textAppBlack,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _pendingProduct = null),
            tooltip: 'Remove product',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation with our support team',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(String chatId) {
    final messagesAsync = ref.watch(chatMessagesProvider(chatId));

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (messages) {
        if (messages.isEmpty) return _buildEmptyState();

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return ChatMessageBubble(message: messages[index]);
          },
        );
      },
    );
  }

  Widget _buildInputBar({String hintText = 'Type a message...'}) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: hintText,
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primaryLaurel,
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sending ? null : _sendText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
