import 'package:flutter/material.dart';

import '../model/payment_channel.dart';
import '../model/seller_profile.dart';
import '../services/local_storage_service.dart';
import '../services/otp_service.dart';

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
  })  : _storage = storage,
        _otpService = otpService {
    _bootstrap();
  }

  final LocalStorageService _storage;
  final OtpService _otpService;

  SellerProfile? _profile;
  AuthStatus _status = AuthStatus.uninitialized;
  String? _pendingPhoneNumber;
  String? _debugCode;

  SellerProfile? get profile => _profile;
  AuthStatus get status => _status;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  String? get debugCode => _debugCode;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _bootstrap() {
    final storedProfile = _storage.readSellerProfile();
    if (storedProfile != null) {
      _profile = storedProfile;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> requestOtp(String phoneNumber) async {
    _status = AuthStatus.requestingOtp;
    notifyListeners();

    final ticket = _otpService.requestCode(phoneNumber, digits: 4);
    _pendingPhoneNumber = phoneNumber;
    _debugCode = ticket.code;
    _status = AuthStatus.otpSent;
    notifyListeners();
  }

  Future<bool> verifyOtp(String code) async {
    if (_pendingPhoneNumber == null) {
      return false;
    }
    _status = AuthStatus.verifyingOtp;
    notifyListeners();

    final isValid = _otpService.verifyCode(
      phoneNumber: _pendingPhoneNumber!,
      code: code,
    );

    if (!isValid) {
      _status = AuthStatus.otpSent;
      notifyListeners();
      return false;
    }

    _profile ??= SellerProfile.empty(_pendingPhoneNumber!);
    await _storage.saveSellerProfile(_profile!);

    _status = AuthStatus.authenticated;
    _pendingPhoneNumber = null;
    _debugCode = null;
    notifyListeners();
    return true;
  }

  Future<void> updateProfile({
    String? displayName,
    String? storeName,
    String? businessType,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      displayName: displayName,
      storeName: storeName,
      businessType: businessType,
      bio: bio,
      avatarUrl: avatarUrl,
      updatedAt: DateTime.now(),
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

    final updatedChannels = normalizedChannel.isPrimary
        ? [
            normalizedChannel,
            ...channels.map((e) => e.copyWith(isPrimary: false)),
          ]
        : [...channels, normalizedChannel];

    _profile = _profile!.copyWith(paymentChannels: updatedChannels);
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
    _profile = _profile!.copyWith(paymentChannels: filtered);
    await _storage.saveSellerProfile(_profile!);
    notifyListeners();
  }

  Future<void> logout() async {
    _profile = null;
    _status = AuthStatus.unauthenticated;
    _pendingPhoneNumber = null;
    _debugCode = null;
    await _storage.clearAll();
    notifyListeners();
  }
}
