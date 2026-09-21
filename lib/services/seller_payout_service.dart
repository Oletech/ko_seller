import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/seller_payout.dart';
import 'firebase_session_service.dart';

/// Reads the marketplace settlement ledger for the signed-in seller.
///
/// Rows are written by the backend when escrow is released and closed when
/// operations records the transfer, so this is read-only on the client. The
/// query filters on `sellerOwnerUid` because that is the field the Firestore
/// rule for `payouts` keys off.
class SellerPayoutService {
  SellerPayoutService({
    FirebaseFirestore? firestore,
    required FirebaseSessionService sessionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _sessionService = sessionService;

  final FirebaseFirestore _firestore;
  final FirebaseSessionService _sessionService;

  Query<Map<String, dynamic>> _payoutQuery(String ownerUid) {
    return _firestore
        .collection('payouts')
        .where('sellerOwnerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .limit(50);
  }

  Stream<List<SellerPayout>> watchPayouts() async* {
    final user = await _sessionService.ensureSignedIn();
    final ownerUid = user?.uid ?? '';
    if (ownerUid.isEmpty) {
      yield const <SellerPayout>[];
      return;
    }

    yield* _payoutQuery(ownerUid).snapshots().map(
          (snapshot) => snapshot.docs
              .map(SellerPayout.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<List<SellerPayout>> fetchPayouts() async {
    final user = await _sessionService.ensureSignedIn();
    final ownerUid = user?.uid ?? '';
    if (ownerUid.isEmpty) return const <SellerPayout>[];

    final snapshot = await _payoutQuery(ownerUid).get();
    return snapshot.docs
        .map(SellerPayout.fromFirestore)
        .toList(growable: false);
  }
}
