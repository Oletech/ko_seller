import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_session_service.dart';

/// Raised when an account cannot be deleted. [blockers] lists the reasons in
/// the seller's own terms so the UI can show them verbatim.
class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message, {this.blockers = const []});

  final String message;
  final List<String> blockers;

  @override
  String toString() => message;
}

class AccountDeletionCheck {
  const AccountDeletionCheck({
    required this.canDelete,
    required this.blockers,
  });

  final bool canDelete;
  final List<String> blockers;
}

/// In-app account deletion, required by App Store Review 5.1.1(v) and Google
/// Play. It runs server-side because a seller cannot be removed while the
/// marketplace still holds buyer money against their orders, and because their
/// listings are referenced by order history.
class AccountDeletionService {
  AccountDeletionService({
    FirebaseFunctions? functions,
    required FirebaseSessionService sessionService,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _sessionService = sessionService;

  final FirebaseFunctions _functions;
  final FirebaseSessionService _sessionService;

  /// Asks the backend whether anything is outstanding, so the seller learns
  /// why before being asked to confirm.
  Future<AccountDeletionCheck> check() async {
    final data = await _call('checkSellerAccountDeletion');
    return AccountDeletionCheck(
      canDelete: data['canDelete'] == true,
      blockers: _blockersFrom(data['blockers']),
    );
  }

  Future<void> deleteAccount() async {
    await _call('deleteSellerAccount');
  }

  Future<Map<String, dynamic>> _call(String name) async {
    await _sessionService.ensureSignedIn();
    try {
      final result = await _functions.httpsCallable(name).call<dynamic>();
      final data = result.data;
      if (data is Map) {
        return data.map((key, value) => MapEntry('$key', value));
      }
      return const <String, dynamic>{};
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final blockers = details is Map ? _blockersFrom(details['blockers']) : const <String>[];
      final message = error.message?.trim();
      throw AccountDeletionException(
        message == null || message.isEmpty
            ? 'Your account could not be deleted right now (${error.code}).'
            : message,
        blockers: blockers,
      );
    } on FirebaseSessionException catch (error) {
      throw AccountDeletionException(error.message);
    } catch (_) {
      throw const AccountDeletionException(
        'Could not reach the marketplace. Check your connection and retry.',
      );
    }
  }

  List<String> _blockersFrom(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
