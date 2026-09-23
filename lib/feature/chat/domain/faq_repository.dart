/// A single canned FAQ question + its auto-reply answer.
class FaqEntry {
  final String id;
  final String question;
  final String answer;

  const FaqEntry({
    required this.id,
    required this.question,
    required this.answer,
  });
}

/// Interface for looking up suggested/canned support questions.
abstract class AutoReplyService {
  List<FaqEntry> getSuggestedQuestions();
  FaqEntry? matchById(String id);
}

/// Static in-memory implementation of [AutoReplyService], seeded with a
/// small set of common support questions. MVP only — no backend lookup.
class StaticAutoReplyService implements AutoReplyService {
  const StaticAutoReplyService();

  static const List<FaqEntry> _entries = [
    FaqEntry(
      id: 'order_status',
      question: 'Where is my order?',
      answer:
          'You can track your order status any time from Orders in your '
          'profile. If it looks stuck or hasn\'t moved in a while, let us '
          'know here and we\'ll look into it.',
    ),
    FaqEntry(
      id: 'cancel_order',
      question: 'How do I cancel or change my order?',
      answer:
          'If your order hasn\'t shipped yet, we can usually cancel or '
          'adjust it for you. Reply here with your order number and what '
          'you\'d like changed.',
    ),
    FaqEntry(
      id: 'payment_issue',
      question: 'My payment failed or was charged twice',
      answer:
          'Sorry about that! Payment issues are usually resolved within '
          '3-5 business days. Send us your order number and we\'ll check '
          'what happened with the charge.',
    ),
    FaqEntry(
      id: 'refund_request',
      question: 'How do I request a refund or return?',
      answer:
          'We can start a return or refund for you here — just tell us the '
          'order number and the reason, and we\'ll walk you through the '
          'next steps.',
    ),
    FaqEntry(
      id: 'other_issue',
      question: 'I have a different account or order issue',
      answer:
          'No problem, tell us a bit more about what\'s going on and a '
          'member of our team will help you sort it out.',
    ),
  ];

  @override
  List<FaqEntry> getSuggestedQuestions() => List.unmodifiable(_entries);

  @override
  FaqEntry? matchById(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
