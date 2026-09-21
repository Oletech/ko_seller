import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderDisplayName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderRole;
  final String senderDisplayName;
  final String text;
  final DateTime? createdAt;

  bool get isSellerMessage => senderRole == 'seller';

  factory ChatMessage.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawCreatedAt = data['createdAt'];
    return ChatMessage(
      id: doc.id,
      senderId: '${data['senderId'] ?? ''}',
      senderRole: '${data['senderRole'] ?? ''}',
      senderDisplayName: '${data['senderDisplayName'] ?? ''}',
      text: '${data['text'] ?? data['message'] ?? ''}',
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : rawCreatedAt is DateTime
              ? rawCreatedAt
              : null,
    );
  }
}
