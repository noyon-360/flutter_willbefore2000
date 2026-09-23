import 'package:flutter/material.dart';

/// Read-only star display, e.g. for an average rating.
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < rating.round();
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: color,
        );
      }),
    );
  }
}

/// Tappable star input for submitting/editing a 1-5 rating.
class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;
  final Color color;

  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 32,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return IconButton(
          onPressed: () => onChanged(starValue),
          icon: Icon(
            starValue <= rating ? Icons.star : Icons.star_border,
            size: size,
            color: color,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        );
      }),
    );
  }
}
