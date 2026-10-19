import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local access gate. Card encryption is provided by secure storage,
/// independently of this password; this is not a password manager.
class VaultAccess {
  VaultAccess({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'lajf_vault_access_v2';
  static const _cardsKey = 'lajf_vault_cards_v1';
  static const _iterations = 600000;
  final FlutterSecureStorage _storage;

  Future<bool> requiresSetup() async {
    final raw = await _storage.read(key: _key);
    if (raw != null) {
      _decode(raw);
      return false;
    }
    // Never allow first-run setup to grant access to legacy private cards.
    final cards = await _storage.read(key: _cardsKey);
    if (cards != null && (jsonDecode(cards) as List).isNotEmpty) {
      throw StateError('Legacy vault requires migration on the original app.');
    }
    return true;
  }

  Future<void> setUp(String password) async {
    if (password.runes.length < 12 || password.trim().isEmpty) {
      throw ArgumentError('Use at least 12 characters.');
    }
    if (!await requiresSetup()) throw StateError('Vault already configured.');
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final verifier = await compute(_derive, (password, salt));
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'version': 2,
        'salt': base64Encode(salt),
        'verifier': base64Encode(verifier),
      }),
    );
  }

  Future<bool> verify(String password) async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return false;
    final record = _decode(raw);
    final actual = await compute(_derive, (password, record.$1));
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ record.$2[i];
    }
    return difference == 0;
  }

  static (List<int>, List<int>) _decode(String raw) {
    final record = jsonDecode(raw) as Map<String, dynamic>;
    if (record['version'] != 2) throw const FormatException('Vault version');
    final salt = base64Decode(record['salt'] as String);
    final verifier = base64Decode(record['verifier'] as String);
    if (salt.length != 32 || verifier.length != 32) {
      throw const FormatException('Invalid vault credential');
    }
    return (salt, verifier);
  }

  static Future<List<int>> _derive((String, List<int>) input) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: input.$1, nonce: input.$2);
    return key.extractBytes();
  }
}
