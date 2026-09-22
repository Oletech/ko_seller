import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../model/payment_channel.dart';
import '../model/seller_profile.dart';
import '../services/firebase_session_service.dart';
import '../services/local_storage_service.dart';
import '../services/otp_service.dart';
import '../services/push_notification_service.dart';
import '../services/seller_payment_method_service.dart';
import '../services/seller_profile_service.dart';

enum AuthStatus {
  uninitialized,
  unauthenticated,
  requestingOtp,
  otpSent,
  verifyingOtp,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required LocalStorageService storage,
    required OtpService otpService,
    required FirebaseSessionService sessionService,
    required SellerProfileService sellerProfileService,
    required SellerPaymentMethodService sellerPaymentMethodService,
    required PushNotificationService pushNotificationService,
  })  : _storage = storage,
        _otpService = otpService,
        _sessionService = sessionService,
        _sellerProfileService = sellerProfileService,
        _sellerPaymentMethodService = sellerPaymentMethodService,
        _pushNotificationService = pushNotificationService {
    _otpService.onAutoVerified = _handleAutoVerified;
    _bootstrap();
    _tokenRefreshSubscription =
        _pushNotificationService.tokenRefreshes.listen(_registerToken);
  }

  final LocalStorageService _storage;
  final OtpService _otpService;
  final FirebaseSessionService _sessionService;
  final SellerProfileService _sellerProfileService;
  final SellerPaymentMethodService _sellerPaymentMethodService;
  final PushNotificationService _pushNotificationService;
  late final StreamSubscription<String> _tokenRefreshSubscription;

  SellerProfile? _profile;
  AuthStatus _status = AuthStatus.uninitialized;
  String? _pendingPhoneNumber;
  String? _debugCode;
  String? _profileError;

  SellerProfile? get profile => _profile;
  AuthStatus get status => _status;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  String? get debugCode => _debugCode;

  /// Set when the seller is signed in but their store could not be loaded, for
  /// example when the store is registered to a different phone number. The
  /// account looks empty in that state, so the UI has to say why.
  String? get profileError => _profileError;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> _bootstrap() async {
    final storedProfile = _storage.readSellerProfile();
    if (storedProfile != null) {
      // currentUser is null for a moment on a cold start while Firebase Auth
      // reads its persisted session off disk. Clearing local storage on that
      // race logs a working seller out and forces a fresh OTP.
      await _sessionService.waitForSessionRestore();
    }
    if (storedProfile != null && _sessionService.currentUser == null) {
      // The cached profile outlived the Firebase session (reinstall, token
      // revocation). Every backend call would fail, so ask for a fresh OTP.
      await _storage.clearAll();
      _profile = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    if (storedProfile != null) {
      _profile = storedProfile;
      _status = AuthStatus.authenticated;
      notifyListeners();
      try {
        final seller = await _sellerProfileService.syncSellerByPhone(
          phoneNumber: storedProfile.phoneNumber,
          localProfile: storedProfile,
        );
        final channels =
            await _sellerPaymentMethodService.fetchPaymentChannels(seller);
        _profile = seller.copyWith(paymentChannels: channels);
        await _storage.saveSellerProfile(_profile!);
        await _registerCurrentDeviceForNotifications();
      } catch (_) {
        _profile = storedProfile;
        await _registerCurrentDeviceForNotifications();
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Returns true when Android verified the device outright and the seller is
  /// already signed in, so the caller must skip the code screen.
  Future<bool> requestOtp(String phoneNumber) async {
    _status = AuthStatus.requestingOtp;
    notifyListeners();

    try {
      final ticket = await _otpService.requestCode(phoneNumber);
      _pendingPhoneNumber = ticket.phoneNumber;
      _debugCode = null;
      if (ticket.autoVerified) {
        await _completeSignIn(ticket.phoneNumber);
        return true;
      }
      _status = AuthStatus.otpSent;
      notifyListeners();
      return false;
    } on OtpException {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> verifyOtp(String code) async {
    if (_pendingPhoneNumber == null) {
      return false;
    }
    _status = AuthStatus.verifyingOtp;
    notifyListeners();

    late final bool isValid;
    try {
      isValid = await _otpService.verifyCode(
        phoneNumber: _pendingPhoneNumber!,
        code: code,
      );
    } on OtpException {
      _status = AuthStatus.otpSent;
      notifyListeners();
      rethrow;
    }

    if (!isValid) {
      _status = AuthStatus.otpSent;
      notifyListeners();
      return false;
    }

    await _completeSignIn(_pendingPhoneNumber!);
    return true;
  }

  /// Android auto-verified the device after the code screen was already up.
  void _handleAutoVerified() {
    final phoneNumber = _pendingPhoneNumber;
    if (phoneNumber == null || _status == AuthStatus.authenticated) {
      return;
    }
    unawaited(_completeSignIn(phoneNumber));
  }

  /// Shared tail of both sign-in paths: load the store, then mark the session
  /// authenticated.
  ///
  /// A failure here is not fatal to the session, but it is not silent either:
  /// the seller is signed in with no store loaded, which looks like an empty
  /// account, so [profileError] carries the reason for the UI to show.
  Future<void> _completeSignIn(String phoneNumber) async {
    final baseProfile = _profile ?? SellerProfile.empty(phoneNumber);
    _profileError = null;
    try {
      final seller = await _sellerProfileService.syncSellerByPhone(
        phoneNumber: phoneNumber,
        localProfile: baseProfile,
      );
      final channels =
          await _sellerPaymentMethodService.fetchPaymentChannels(seller);
      _profile = seller.copyWith(paymentChannels: channels);
      await _storage.saveSellerProfile(_profile!);
      await _registerCurrentDeviceForNotifications();
    } on SellerProfileException catch (error) {
      _profileError = error.message;
      _profile = baseProfile;
      await _storage.saveSellerProfile(_profile!);
    } catch (error) {
      _profileError =
          'Signed in, but your store could not be loaded. Pull down to retry.';
      _profile = baseProfile;
      await _storage.saveSellerProfile(_profile!);
    }

    _status = AuthStatus.authenticated;
    _pendingPhoneNumber = null;
    _debugCode = null;
    notifyListeners();
  }

  void clearProfileError() {
    if (_profileError == null) return;
    _profileError = null;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? displayName,
    String? storeName,
    String? businessType,
    String? email,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      displayName: displayName,
      storeName: storeName,
      businessType: businessType,
      email: email,
      bio: bio,
      avatarUrl: avatarUrl,
      updatedAt: DateTime.now(),
    );
    try {
      _profile = await _sellerProfileService.updateSellerProfile(_profile!);
    } catch (_) {}
    await _storage.saveSellerProfile(_profile!);
    notifyListeners();
  }

  Future<void> _registerCurrentDeviceForNotifications() async {
    final token = await _pushNotificationService.getToken();
    await _registerToken(token);
  }

  Future<void> _registerToken(String? token) async {
    final seller = _profile;
    if (seller == null || !seller.notificationsEnabled || token == null) {
      return;
    }
    try {
      await _sellerProfileService.registerNotificationToken(
        seller: seller,
        token: token,
      );
    } catch (_) {}
  }

  Future<void> uploadProfileImage(File imageFile) async {
    if (_profile == null) return;
    final updated = await _sellerProfileService.uploadSellerLogo(
      profile: _profile!,
      imageFile: imageFile,
    );
    _profile = updated.copyWith(
      paymentChannels: _profile!.paymentChannels,
      inventoryValue: _profile!.inventoryValue,
      salesValue: _profile!.salesValue,
      totalOrders: _profile!.totalOrders,
      bio: _profile!.bio,
      notificationsEnabled: _profile!.notificationsEnabled,
    );
    await _storage.saveSellerProfile(_profile!);
    notifyListeners();
  }

  Future<void> addPaymentChannel(PaymentChannel channel) async {
    if (_profile == null) return;
    final channels = List<PaymentChannel>.from(_profile!.paymentChannels);
    final normalizedChannel = channel.isPrimary
        ? channel
        : channel.copyWith(isPrimary: channels.isEmpty);

    final persisted = await _sellerPaymentMethodService.addPaymentChannel(
      seller: _profile!,
      channel: normalizedChannel,
    );
    final normalizedChannels = normalizedChannel.isPrimary
        ? [
            persisted.copyWith(isPrimary: true),
            ...channels.map((e) => e.copyWith(isPrimary: false)),
          ]
        : [...channels, persisted];

    _profile = _profile!.copyWith(paymentChannels: normalizedChannels);
    await _storage.saveSellerProfile(_profile!);
    notifyListeners();
  }

  Future<void> setPrimaryChannel(String channelId) async {
    if (_profile == null) return;
    final updatedChannels = _profile!.paymentChannels
        .map(
          (channel) => channel.copyWith(
            isPrimary: channel.id == channelId,
          ),
        )
        .toList();

    await _sellerPaymentMethodService.setPrimaryChannel(
      seller: _profile!,
      channelId: channelId,
    );
    _profile = _profile!.copyWith(paymentChannels: updatedChannels);
    await _storage.saveSellerProfile(_profile!);
    notifyListeners();
  }

  Future<void> removeChannel(String channelId) async {
    if (_profile == null) return;
    final filtered = _profile!.paymentChannels
        .where((channel) => channel.id != channelId)
        .toList();
    if (filtered.isNotEmpty && !filtered.any((element) => element.isPrimary)) {
      filtered[0] = filtered[0].copyWith(isPrimary: true);
    }
    await _sellerPaymentMethodService.removePaymentChannel(channelId);
    if (filtered.isNotEmpty) {
      await _sellerPaymentMethodService.setPrimaryChannel(
        seller: _profile!,
        channelId: filtered.first.id,
      );
    }
    _profile = _profile!.copyWith(paymentChannels: filtered);
    await _storage.saveSellerProfile(_profile!);
    notifyListeners();
  }

  Future<void> logout() async {
    final seller = _profile;
    final token = await _pushNotificationService.getToken();
    if (seller != null && token != null) {
      try {
        await _sellerProfileService.unregisterNotificationToken(
          seller: seller,
          token: token,
        );
      } catch (_) {}
    }
    _profile = null;
    _status = AuthStatus.unauthenticated;
    _pendingPhoneNumber = null;
    _debugCode = null;
    await _sessionService.signOut();
    await _storage.clearAll();
    notifyListeners();
  }

  @override
  void dispose() {
    _tokenRefreshSubscription.cancel();
    super.dispose();
  }
}
