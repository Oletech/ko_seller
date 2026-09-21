import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/chat_message.dart';
import '../model/order_item.dart';
import '../model/seller_profile.dart';

/// Order chat shared with the buyer app. Conversation ids are derived the same
/// way on both sides (`order__seller__buyer`). Firestore rules grant access by
/// auth uid, so the seller's uid is always part of `participantIds`; the
/// `enrichConversationParticipants` Cloud Function adds it to threads the
/// buyer opened first.
class OrderChatService {
  OrderChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _safeSegment(String value, String fallback) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized.replaceAll(RegExp(r'[^\w.-]+'), '_');
  }

  String buildConversationId({
    required String orderDocumentId,
    required String sellerId,
    required String buyerId,
  }) {
    return [
      _safeSegment(orderDocumentId, 'order'),
      _safeSegment(sellerId, 'seller'),
      _safeSegment(buyerId, 'buyer'),
    ].join('__');
  }

  DocumentReference<Map<String, dynamic>> conversationRef(
    String conversationId,
  ) =>
      _firestore.collection('conversations').doc(conversationId);

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return conversationRef(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ChatMessage.fromFirestore)
              .where((message) => message.text.trim().isNotEmpty)
              .toList(growable: false),
        );
  }

  String _sellerIdFor(SellerOrder order, SellerProfile seller) {
    return order.product.sellerId.trim().isNotEmpty
        ? order.product.sellerId.trim()
        : seller.productSellerId.trim();
  }

  String _sellerDisplayName(SellerProfile seller) {
    if (seller.storeName.trim().isNotEmpty) return seller.storeName.trim();
    if (seller.displayName.trim().isNotEmpty) return seller.displayName.trim();
    return 'Seller';
  }

  Future<String> ensureConversation({
    required SellerOrder order,
    required SellerProfile seller,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw StateError('Sign in again before messaging the buyer.');
    }

    final sellerId = _sellerIdFor(order, seller);
    final buyerId = order.buyer.userId.trim();
    final conversationId = buildConversationId(
      orderDocumentId: order.orderDocumentId.trim(),
      sellerId: sellerId,
      buyerId: buyerId,
    );

    final docRef = conversationRef(conversationId);
    final existing = await docRef.get();

    if (existing.exists) {
      // participantIds, buyerId and sellerId are immutable once created
      // (rules); only refresh the seller's display metadata.
      await docRef.set({
        'sellerName': _sellerDisplayName(seller),
        'sellerImage': seller.avatarUrl.trim(),
        'sellerFirestoreDocId': seller.firestoreDocId.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return conversationId;
    }

    final sellerParticipantIds = <String>{
      sellerId,
      seller.id.trim(),
      seller.firestoreDocId.trim(),
    }.where((value) => value.isNotEmpty).toList(growable: false);

    await docRef.set({
      'id': conversationId,
      'orderDocumentId': order.orderDocumentId.trim(),
      'orderNumber': order.orderNumber.trim(),
      'productId': order.product.productId.trim(),
      'productName': order.product.title.trim(),
      'buyerId': buyerId,
      'buyerName': order.buyer.name.trim(),
      'buyerImage': '',
      'sellerId': sellerId,
      'sellerFirestoreDocId': seller.firestoreDocId.trim(),
      'sellerParticipantIds': sellerParticipantIds,
      'sellerOwnerUid': uid,
      'sellerOwnerUids': [uid],
      'sellerName': _sellerDisplayName(seller),
      'sellerImage': seller.avatarUrl.trim(),
      'participantIds': <String>{buyerId, uid, ...sellerParticipantIds}
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      'buyerUnreadCount': 0,
      'sellerUnreadCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return conversationId;
  }

  Future<void> sendSellerMessage({
    required SellerOrder order,
    required SellerProfile seller,
    required String text,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }

    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw StateError('Sign in again before messaging the buyer.');
    }

    final conversationId =
        await ensureConversation(order: order, seller: seller);
    await conversationRef(conversationId).collection('messages').add({
      'senderId': uid,
      'senderSellerId': _sellerIdFor(order, seller),
      'senderRole': 'seller',
      'senderDisplayName': _sellerDisplayName(seller),
      'text': normalizedText,
      'createdAt': FieldValue.serverTimestamp(),
      'orderDocumentId': order.orderDocumentId.trim(),
      'orderNumber': order.orderNumber.trim(),
    });
  }
}
