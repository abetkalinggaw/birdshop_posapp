import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureAuthStore implements AuthStore {
  static const _storage = FlutterSecureStorage();
  final String key;
  const SecureAuthStore({this.key = 'exsha.staff.v1'});
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

class PinHasher {
  final int iterations;
  const PinHasher({this.iterations = 600000});

  Future<Map<String, dynamic>> hash(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final digest = await _derive(pin, salt, iterations);
    return {
      'salt': base64Encode(salt),
      'hash': base64Encode(digest),
      'iterations': iterations,
    };
  }

  Future<bool> verify(String pin, Map<String, dynamic> credential) async {
    final expected = base64Decode(credential['hash'] as String);
    final actual = await _derive(
      pin,
      base64Decode(credential['salt'] as String),
      credential['iterations'] as int,
    );
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  Future<List<int>> _derive(String pin, List<int> salt, int count) =>
      Isolate.run(() async {
        final key = await Pbkdf2.hmacSha256(
          iterations: count,
          bits: 256,
        ).deriveKeyFromPassword(password: pin, nonce: salt);
        return key.extractBytes();
      });
}
