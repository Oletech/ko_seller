import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/payment_channel.dart';
import '../model/seller_profile.dart';
import 'firebase_session_service.dart';

class SellerPaymentMethodService {
  SellerPaymentMethodService({
    FirebaseFirestore? firestore,
    required FirebaseSessionService sessionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _sessionService = sessionService;

  final FirebaseFirestore _firestore;
  final FirebaseSessionService _sessionService;

  CollectionReference<Map<String, dynamic>> get _methods =>
      _firestore.collection('seller_payment_method');

  Future<List<PaymentChannel>> fetchPaymentChannels(
      SellerProfile seller) async {
    await _sessionService.ensureSignedIn();
    final sellerIds = seller.productSellerIds;
    if (sellerIds.isEmpty) return const [];

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    if (sellerIds.length == 1) {
      final snapshot =
          await _methods.where('sellerid', isEqualTo: sellerIds.first).get();
      docs.addAll(snapshot.docs);
    } else {
      final snapshot =
          await _methods.where('sellerid', whereIn: sellerIds).get();
      docs.addAll(snapshot.docs);
    }

    final unique = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in docs) {
      unique[doc.id] = doc;
    }

    final channels = unique.values.map(_toPaymentChannel).toList()
      ..sort((a, b) {
        if (a.isPrimary == b.isPrimary) {
          return a.displayName.compareTo(b.displayName);
        }
        return a.isPrimary ? -1 : 1;
      });
    return channels;
  }

  Future<PaymentChannel> addPaymentChannel({
    required SellerProfile seller,
    required PaymentChannel channel,
  }) async {
    await _sessionService.ensureSignedIn();
    final docId = channel.id.isEmpty ? _methods.doc().id : channel.id;
    final normalized = channel.copyWith(id: docId);

    await _methods.doc(docId).set(
          _buildPayload(
            seller: seller,
            channel: normalized,
            isCreate: true,
          ),
          SetOptions(merge: true),
        );

    if (normalized.isPrimary) {
      await setPrimaryChannel(seller: seller, channelId: normalized.id);
    }

    return normalized;
  }

  Future<void> setPrimaryChannel({
    required SellerProfile seller,
    required String channelId,
  }) async {
    await _sessionService.ensureSignedIn();
    final existing = await fetchPaymentChannels(seller);
    final batch = _firestore.batch();

    for (final channel in existing) {
      batch.set(
        _methods.doc(channel.id),
        {
          'isPrimary': channel.id == channelId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> removePaymentChannel(String channelId) async {
    await _sessionService.ensureSignedIn();
    await _methods.doc(channelId).delete();
  }

  Map<String, dynamic> _buildPayload({
    required SellerProfile seller,
    required PaymentChannel channel,
    required bool isCreate,
  }) {
    return {
      'paymentMethodId': channel.id,
      'sellerid': seller.productSellerId,
      'sellerFirestoreDocId': seller.firestoreDocId,
      'type': channel.type.name,
      'paymentType': channel.type.label,
      'displayName': channel.displayName.trim(),
      'accountNumber': channel.accountNumber.trim(),
      'instructions': channel.instructions.trim(),
      'isPrimary': channel.isPrimary,
      'active': true,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PaymentChannel _toPaymentChannel(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return PaymentChannel(
      id: '${data['paymentMethodId'] ?? doc.id}',
      type: PaymentChannelTypeX.fromString(
        '${data['type'] ?? PaymentChannelType.custom.name}',
      ),
      displayName: '${data['displayName'] ?? ''}',
      accountNumber: '${data['accountNumber'] ?? ''}',
      instructions: '${data['instructions'] ?? ''}',
      isPrimary: data['isPrimary'] as bool? ?? false,
    );
  }
}
