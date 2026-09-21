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

  /// Payout channels are read by `ownerUid`, not by `sellerid`: Firestore
  /// evaluates rules against the query, and the rule on this collection keys
  /// off `ownerUid`, so a `sellerid` query is rejected before it runs.
  Future<List<PaymentChannel>> fetchPaymentChannels(
      SellerProfile seller) async {
    final user = await _sessionService.ensureSignedIn();
    final ownerUid = user?.uid ?? '';
    if (ownerUid.isEmpty) return const [];

    final snapshot = await _methods.where('ownerUid', isEqualTo: ownerUid).get();
    final sellerIds = seller.productSellerIds.toSet();
    final unique = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final docSellerId = '${data['sellerid'] ?? ''}'.trim();
      // One account can own more than one store; keep this store's channels.
      if (sellerIds.isNotEmpty &&
          docSellerId.isNotEmpty &&
          !sellerIds.contains(docSellerId)) {
        continue;
      }
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
    final ownerUid = _sessionService.currentUser?.uid ?? '';
    return {
      'ownerUid': ownerUid,
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
