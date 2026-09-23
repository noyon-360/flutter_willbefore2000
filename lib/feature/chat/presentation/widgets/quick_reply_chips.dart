import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/faq_repository.dart';

/// Horizontal-wrapping list of suggested question chips.
class QuickReplyChips extends StatelessWidget {
  final List<FaqEntry> entries;
  final ValueChanged<FaqEntry> onSelected;
  final bool enabled;

  const QuickReplyChips({
    super.key,
    required this.entries,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'Suggested questions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries.map((entry) {
              return ActionChip(
                label: Text(
                  entry.question,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: AppColors.primaryLaurel.withValues(
                  alpha: 0.08,
                ),
                side: BorderSide(
                  color: AppColors.primaryLaurel.withValues(alpha: 0.4),
                ),
                labelStyle: const TextStyle(color: AppColors.textAppLaurel),
                onPressed: enabled ? () => onSelected(entry) : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
