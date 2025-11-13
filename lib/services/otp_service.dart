import 'dart:math';

class OtpTicket {
  final String phoneNumber;
  final String code;
  final DateTime expiresAt;

  OtpTicket({
    required this.phoneNumber,
    required this.code,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class OtpService {
  OtpTicket? _latestTicket;
  final Random _random = Random();

  OtpTicket requestCode(String phoneNumber, {int digits = 4}) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits; i++) {
      buffer.write(_random.nextInt(10));
    }
    final ticket = OtpTicket(
      phoneNumber: phoneNumber,
      code: buffer.toString(),
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
    );
    _latestTicket = ticket;
    return ticket;
  }

  bool verifyCode({
    required String phoneNumber,
    required String code,
  }) {
    if (_latestTicket == null) return false;
    if (_latestTicket!.phoneNumber != phoneNumber) return false;
    if (_latestTicket!.isExpired) return false;
    final isValid = _latestTicket!.code == code;
    if (isValid) {
      _latestTicket = null;
    }
    return isValid;
  }

  Duration? timeLeft() {
    if (_latestTicket == null) return null;
    final difference = _latestTicket!.expiresAt.difference(DateTime.now());
    if (difference.isNegative) return Duration.zero;
    return difference;
  }
}
