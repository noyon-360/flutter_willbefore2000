import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/chat_message_model.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;

    final bubbleColor = isUser ? AppColors.primaryLaurel : Colors.grey[200];
    final textColor = isUser ? Colors.white : AppColors.textAppBlack;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                message.isFromBot ? 'Support Bot' : 'Support',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 2),
                bottomRight: Radius.circular(isUser ? 2 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.hasProduct) ...[
                  _ProductChip(message: message, isUser: isUser),
                  const SizedBox(height: 6),
                ],
                Text(
                  message.text,
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
              ],
            ),
          ),
          if (message.createdAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                timeago.format(message.createdAt!),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;

  const _ProductChip({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final fg = isUser ? Colors.white : AppColors.textAppBlack;
    final bg = isUser ? Colors.white.withValues(alpha: 0.15) : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.pushNamed(
        'product_details',
        pathParameters: {'productId': message.productId!},
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child:
                  message.productImage != null &&
                      message.productImage!.isNotEmpty
                  ? Image.network(
                      message.productImage!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 32,
                        height: 32,
                        color: Colors.grey[300],
                      ),
                    )
                  : Container(width: 32, height: 32, color: Colors.grey[300]),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.productTitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  if (message.productPrice != null)
                    Text(
                      '\$${message.productPrice!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
