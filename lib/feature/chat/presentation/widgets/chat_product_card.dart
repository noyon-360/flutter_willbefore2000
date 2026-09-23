import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/chat_model.dart';

/// Small product-context card shown at the top of a chat when the
/// conversation is about a specific product.
class ChatProductCard extends StatelessWidget {
  final ChatModel chat;

  const ChatProductCard({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    if (!chat.hasProduct) return const SizedBox.shrink();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.pushNamed(
        'product_details',
        pathParameters: {'productId': chat.productId!},
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
              child: chat.productImage != null && chat.productImage!.isNotEmpty
                  ? Image.network(
                      chat.productImage!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.productTitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textAppBlack,
                    ),
                  ),
                  if (chat.productPrice != null)
                    Text(
                      '\$${chat.productPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryLaurel,
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

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 20, color: Colors.grey),
    );
  }
}
