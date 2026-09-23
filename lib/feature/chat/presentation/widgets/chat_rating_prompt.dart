import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Inline card shown to the customer once a support chat is closed and
/// hasn't been rated yet. Rating is customer-facing only.
class ChatRatingPrompt extends StatefulWidget {
  final bool submitting;
  final Future<void> Function(int rating, String? comment) onSubmit;

  const ChatRatingPrompt({
    super.key,
    required this.onSubmit,
    this.submitting = false,
  });

  @override
  State<ChatRatingPrompt> createState() => _ChatRatingPromptState();
}

class _ChatRatingPromptState extends State<ChatRatingPrompt> {
  int _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How would you rate our support?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Your rating helps us improve our service',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.submitting
                    ? null
                    : () => setState(() => _rating = starIndex),
                icon: Icon(
                  starIndex <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 28,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            enabled: !widget.submitting,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tell us more... (optional)',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_rating == 0 || widget.submitting)
                  ? null
                  : () => widget.onSubmit(
                      _rating,
                      _commentController.text.trim().isEmpty
                          ? null
                          : _commentController.text.trim(),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLaurel,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: widget.submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
