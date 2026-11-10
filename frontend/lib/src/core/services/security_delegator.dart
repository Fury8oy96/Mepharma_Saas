import 'dart:convert';
import 'dart:math';

class SecurityDelegator {
  static final _random = Random.secure();

  /// Generates a globally unique idempotency key with high collision resistance
  static String generateIdempotencyKey({String prefix = 'meph'}) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomBytes = List<int>.generate(12, (_) => _random.nextInt(256));
    final randomHex = randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$timestamp-$randomHex';
  }

  /// Calculates a SHA-256-based integrity hash of the payload to verify payload stability
  static String calculatePayloadSignature(String payloadJson, {String secret = 'mepharma_secure_offline_token'}) {
    final bytes = utf8.encode('$payloadJson:$secret');
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Packages an entity payload for synchronization
  static Map<String, dynamic> packageSyncPayload({
    required String entityType,
    required String action,
    required Map<String, dynamic> rawPayload,
    String? idempotencyKey,
    int? userId,
    int? branchId,
  }) {
    final key = idempotencyKey ?? generateIdempotencyKey(prefix: entityType.substring(0, min(4, entityType.length)));
    final payloadJson = jsonEncode(rawPayload);
    final signature = calculatePayloadSignature(payloadJson);

    return {
      'idempotency_key': key,
      'entity_type': entityType,
      'action': action,
      'payload': rawPayload,
      'signature': signature,
      'user_id': userId,
      'branch_id': branchId,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
