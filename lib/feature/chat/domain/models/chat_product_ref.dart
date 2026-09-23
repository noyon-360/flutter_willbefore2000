/// A lightweight reference to a product a chat message is about.
///
/// Passed from the product detail screen into [ChatScreen] as pending
/// context, then attached to the message the user actually sends (rather
/// than being posted as a message on its own).
class ChatProductRef {
  final String id;
  final String title;
  final String? image;
  final double? price;

  const ChatProductRef({
    required this.id,
    required this.title,
    this.image,
    this.price,
  });
}
