import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class OtpException implements Exception {
  const OtpException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OtpTicket {
  final String phoneNumber;
  final String verificationId;
  final DateTime expiresAt;

  /// True when Android verified the device without ever sending an SMS. The
  /// caller is already signed in and must not be sent to the code screen.
  final bool autoVerified;

  OtpTicket({
    required this.phoneNumber,
    required this.verificationId,
    required this.expiresAt,
    this.autoVerified = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class OtpService {
  OtpService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  OtpTicket? _latestTicket;
  int? _resendToken;
  PhoneAuthCredential? _autoVerifiedCredential;
  bool _autoSignedIn = false;

  /// Fired when Android auto-verified the device and signed the seller in
  /// after the code screen was already showing. Without it the seller sits
  /// waiting for an SMS that was never sent.
  void Function()? onAutoVerified;

  Future<OtpTicket> requestCode(String phoneNumber) async {
    final completer = Completer<OtpTicket>();
    _autoVerifiedCredential = null;
    _autoSignedIn = false;

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        // Play Integrity can verify the device outright, in which case no SMS
        // is ever sent and codeSent never fires. Signing in here is the only
        // way the seller gets past this screen.
        verificationCompleted: (credential) async {
          _autoVerifiedCredential = credential;
          try {
            await _auth.signInWithCredential(credential);
            _autoSignedIn = true;
            _latestTicket = null;
            _resendToken = null;
            if (!completer.isCompleted) {
              completer.complete(
                OtpTicket(
                  phoneNumber: phoneNumber,
                  verificationId: '',
                  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
                  autoVerified: true,
                ),
              );
            } else {
              // The code screen is already up; tell it to move on.
              onAutoVerified?.call();
            }
          } catch (_) {
            // Fall back to the typed code; codeSent may still arrive.
          }
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) {
            completer.completeError(OtpException(_messageForAuthError(error)));
          }
        },
        codeSent: (verificationId, resendToken) {
          _resendToken = resendToken;
          final ticket = OtpTicket(
            phoneNumber: phoneNumber,
            verificationId: verificationId,
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );
          _latestTicket = ticket;
          if (!completer.isCompleted) {
            completer.complete(ticket);
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _latestTicket ??= OtpTicket(
            phoneNumber: phoneNumber,
            verificationId: verificationId,
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );
        },
      );
    } on FirebaseAuthException catch (error) {
      throw OtpException(_messageForAuthError(error));
    }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw const OtpException(
        'Firebase did not send an OTP in time. Check the phone number and try again.',
      ),
    );
  }

  Future<bool> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    // Auto-verification may have signed the seller in while the code screen
    // was open. Whatever they typed is then irrelevant.
    if (_autoSignedIn && _auth.currentUser != null) {
      _autoSignedIn = false;
      _autoVerifiedCredential = null;
      return true;
    }
    if (_latestTicket == null) return false;
    if (_latestTicket!.phoneNumber != phoneNumber) return false;
    if (_latestTicket!.isExpired) return false;

    final credential = _autoVerifiedCredential ??
        PhoneAuthProvider.credential(
          verificationId: _latestTicket!.verificationId,
          smsCode: code.trim(),
        );

    try {
      await _auth.signInWithCredential(credential);
      _latestTicket = null;
      _resendToken = null;
      _autoVerifiedCredential = null;
      return true;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-verification-code' ||
          error.code == 'invalid-verification-id' ||
          error.code == 'session-expired') {
        return false;
      }
      throw OtpException(_messageForAuthError(error));
    }
  }

  Duration? timeLeft() {
    if (_latestTicket == null) return null;
    final difference = _latestTicket!.expiresAt.difference(DateTime.now());
    if (difference.isNegative) return Duration.zero;
    return difference;
  }

  String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid. Use the full number with the country code.';
      case 'too-many-requests':
        return 'Too many OTP requests were made. Wait a few minutes and try again.';
      case 'quota-exceeded':
        return 'Firebase SMS quota has been exceeded for this project.';
      case 'operation-not-allowed':
        return 'Phone sign-in is disabled. Enable Phone under Firebase Authentication > Sign-in method.';
      case 'captcha-check-failed':
      case 'missing-client-identifier':
        return 'Firebase could not verify this app. Check the iOS Firebase URL scheme and APNs/reCAPTCHA setup.';
      case 'network-request-failed':
        return 'The device could not reach Firebase. Check the network and try again.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Unable to send or verify the OTP right now.';
    }
  }
}
