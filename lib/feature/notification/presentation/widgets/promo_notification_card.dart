import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_endpoint.dart';

class PromoNotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRead;

  const PromoNotificationCard({
    super.key,
    required this.data,
    required this.onRead,
  });

  String get _code {
    final metadata = data['metadata'];
    return metadata is Map ? (metadata['code'] ?? '').toString() : '';
  }

  DateTime? get _endDate {
    final endDate = data['endDate'];
    return endDate is int ? DateTime.fromMillisecondsSinceEpoch(endDate) : null;
  }

  bool get _isExpired {
    final endDate = _endDate;
    return endDate != null && DateTime.now().isAfter(endDate);
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _code));
    onRead();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$_code copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = data['read'] == true;
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final timestamp = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isRead ? 0 : 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRead
            ? BorderSide.none
            : const BorderSide(color: AppColors.primaryLaurel),
      ),
      child: InkWell(
        onTap: onRead,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 2,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title']?.toString() ?? 'Special offer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                      color: AppColors.textAppBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(data['message']?.toString() ?? ''),
                  if (_code.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCodeBox(context),
                  ],
                  const SizedBox(height: 8),
                  _buildFooter(context, timestamp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              _code,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: _isExpired ? Colors.grey : AppColors.textAppBlack,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _isExpired ? null : () => _copyCode(context),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryLaurel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, DateTime? timestamp) {
    final endDate = _endDate;
    final details = [
      if (_isExpired)
        'Expired'
      else if (endDate != null)
        'Ends ${DateFormat('MMM d, h:mm a').format(endDate)}',
      if (timestamp != null) timeago.format(timestamp),
    ].join(' • ');

    return Row(
      children: [
        Expanded(
          child: Text(
            details,
            style: TextStyle(
              fontSize: 12,
              color: _isExpired ? Colors.red : Colors.grey[600],
            ),
          ),
        ),
        if (!_isExpired)
          TextButton(
            onPressed: () {
              onRead();
              context.go(RoutePaths.cart);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryLaurel,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Go to Cart'),
          ),
      ],
    );
  }
}
