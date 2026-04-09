import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../model/seller_profile.dart';
import 'firebase_storage_upload_exception.dart';
import 'firebase_session_service.dart';

class SellerProfileService {
  SellerProfileService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    required FirebaseSessionService sessionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _sessionService = sessionService;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseSessionService _sessionService;

  CollectionReference<Map<String, dynamic>> get _sellers =>
      _firestore.collection('seller');

  Future<SellerProfile> syncSellerByPhone({
    required String phoneNumber,
    SellerProfile? localProfile,
  }) async {
    await _sessionService.ensureSignedIn();

    final existingDoc = await _findSellerDocumentByPhone(phoneNumber);
    if (existingDoc != null) {
      return _toSellerProfile(existingDoc, localProfile: localProfile);
    }

    final created = await _createSeller(phoneNumber, localProfile: localProfile);
    return _toSellerProfile(created, localProfile: localProfile);
  }

  Future<SellerProfile> updateSellerProfile(SellerProfile profile) async {
    await _sessionService.ensureSignedIn();

    final existingByPhone = profile.firestoreDocId.isEmpty
        ? await _findSellerDocumentByPhone(profile.phoneNumber)
        : null;
    final docRef = profile.firestoreDocId.isNotEmpty
        ? _sellers.doc(profile.firestoreDocId)
        : existingByPhone != null
            ? _sellers.doc(existingByPhone.id)
            : _sellers.doc();
    final isNew = profile.firestoreDocId.isEmpty && existingByPhone == null;
    final payload = _buildSellerPayload(
      profile.copyWith(
        firestoreDocId: docRef.id,
        id: profile.id.isEmpty ? docRef.id : profile.id,
      ),
      isCreate: isNew,
    );

    await docRef.set(payload, SetOptions(merge: true));
    final snapshot = await docRef.get();
    return _toSellerProfile(snapshot, localProfile: profile);
  }

  Future<SellerProfile> uploadSellerLogo({
    required SellerProfile profile,
    required File imageFile,
  }) async {
    await _sessionService.ensureSignedIn();

    final existingByPhone = profile.firestoreDocId.isEmpty
        ? await _findSellerDocumentByPhone(profile.phoneNumber)
        : null;
    final docRef = profile.firestoreDocId.isNotEmpty
        ? _sellers.doc(profile.firestoreDocId)
        : existingByPhone != null
            ? _sellers.doc(existingByPhone.id)
            : _sellers.doc();
    final sellerId = profile.id.isNotEmpty ? profile.id : docRef.id;
    final storageRef = _storage.ref().child(
          'seller_logos/$sellerId/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

    late final String logoUrl;
    try {
      await storageRef.putFile(imageFile);
      logoUrl = await storageRef.getDownloadURL();
    } catch (error) {
      throw mapFirebaseStorageUploadException(error);
    }

    final updatedProfile = profile.copyWith(
      id: sellerId,
      firestoreDocId: docRef.id,
      avatarUrl: logoUrl,
      updatedAt: DateTime.now(),
    );

    await docRef.set(
      _buildSellerPayload(
        updatedProfile,
        isCreate: profile.firestoreDocId.isEmpty && existingByPhone == null,
      ),
      SetOptions(merge: true),
    );

    final snapshot = await docRef.get();
    return _toSellerProfile(snapshot, localProfile: updatedProfile);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findSellerDocumentByPhone(
    String phoneNumber,
  ) async {
    for (final candidate in _phoneCandidates(phoneNumber)) {
      final snapshot =
          await _sellers.where('phone', isEqualTo: candidate).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first;
      }
    }
    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _createSeller(
    String phoneNumber, {
    SellerProfile? localProfile,
  }) async {
    final docRef = _sellers.doc();
    final normalized = (localProfile ?? SellerProfile.empty(phoneNumber))
        .copyWith(id: docRef.id, firestoreDocId: docRef.id, phoneNumber: phoneNumber);
    await docRef.set(_buildSellerPayload(normalized, isCreate: true));
    return docRef.get();
  }

  Map<String, dynamic> _buildSellerPayload(
    SellerProfile profile, {
    required bool isCreate,
  }) {
    final storeName = profile.storeName.trim().isNotEmpty
        ? profile.storeName.trim()
        : profile.displayName.trim();

    return {
      'sellerid': profile.id.isEmpty ? profile.firestoreDocId : profile.id,
      'sellerStatus': profile.sellerStatus,
      'storeName': storeName,
      'storeAddress': '',
      'BusinessName': storeName,
      'BusinessType': profile.businessType.trim(),
      'email': profile.email.trim(),
      'phone': profile.phoneNumber.trim(),
      'logo': profile.avatarUrl.trim(),
      'follower': profile.followerCount,
      'areaServed': '',
      'brand': const [],
      'hasOfferCatalog': false,
      'knowsAbout': '',
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SellerProfile _toSellerProfile(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    SellerProfile? localProfile,
  }) {
    final data = doc.data() ?? const {};
    final storeName = '${data['storeName'] ?? data['BusinessName'] ?? ''}'.trim();
    final phone = '${data['phone'] ?? localProfile?.phoneNumber ?? ''}'.trim();

    return SellerProfile(
      id: '${data['sellerid'] ?? doc.id}',
      firestoreDocId: doc.id,
      phoneNumber: phone,
      email: '${data['email'] ?? localProfile?.email ?? ''}'.trim(),
      displayName: storeName,
      storeName: storeName,
      businessType: '${data['BusinessType'] ?? localProfile?.businessType ?? ''}'
          .trim(),
      bio: localProfile?.bio ??
          'Let customers know what makes your store special.',
      inventoryValue: localProfile?.inventoryValue ?? 0,
      salesValue: localProfile?.salesValue ?? 0,
      totalOrders: localProfile?.totalOrders ?? 0,
      avatarUrl: '${data['logo'] ?? localProfile?.avatarUrl ?? ''}'.trim(),
      followerCount: (data['follower'] as num?)?.toInt() ??
          localProfile?.followerCount ??
          0,
      paymentChannels: localProfile?.paymentChannels ?? const [],
      updatedAt: _asDateTime(
        data['updatedAt'],
        fallback: _asDateTime(data['createdAt']),
      ),
      notificationsEnabled: localProfile?.notificationsEnabled ?? true,
      sellerStatus: data['sellerStatus'] as bool? ?? true,
    );
  }

  Iterable<String> _phoneCandidates(String input) sync* {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    final candidates = <String>{
      trimmed,
      digits,
    };

    if (digits.startsWith('255')) {
      candidates.add('+$digits');
      candidates.add('0${digits.substring(3)}');
    }
    if (digits.startsWith('0')) {
      candidates.add('+255${digits.substring(1)}');
      candidates.add('255${digits.substring(1)}');
    }

    yield* candidates.where((value) => value.isNotEmpty);
  }

  DateTime _asDateTime(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    }
    return fallback ?? DateTime.now();
  }
}
