/// World of Warcraft packet header encryption
/// 
/// Implements the AuthCrypt system used to encrypt/decrypt packet headers
/// after successful authentication with the world server.

import 'dart:typed_data';
import '../crypto/arc4.dart';
import '../crypto/utils.dart';

/// Authentication encryption/decryption handler
/// 
/// After successful AUTH_SESSION, all packet headers are encrypted using
/// ARC4 (RC4) with keys derived from the session key via HMAC-SHA1.
/// 
/// The server uses different keys for encryption and decryption:
/// - Server encryption key (client decryption): for packets FROM server
/// - Client decryption key (server encryption): for packets TO server
class AuthCrypt {
  late final ARC4 _serverEncrypt; // For encrypting packets we send
  late final ARC4 _clientDecrypt; // For decrypting packets we receive
  bool _initialized = false;

  /// Server encryption key seed (used by server to encrypt, client to decrypt received packets)
  static final Uint8List _serverEncryptionKey = Uint8List.fromList([
    0xCC, 0x98, 0xAE, 0x04, 0xE8, 0x97, 0xEA, 0xCA,
    0x12, 0xDD, 0xC0, 0x93, 0x42, 0x91, 0x53, 0x57,
  ]);

  /// Server decryption key seed (used by client to encrypt, server to decrypt received packets)
  static final Uint8List _serverDecryptionKey = Uint8List.fromList([
    0xC2, 0xB3, 0x72, 0x3C, 0xC6, 0xAE, 0xD9, 0xB5,
    0x34, 0x3C, 0x53, 0xEE, 0x2F, 0x43, 0x67, 0xCE,
  ]);

  /// Initialize encryption with session key
  /// 
  /// Derives two separate ARC4 keys using HMAC-SHA1:
  /// - One for encrypting data we send (from server decryption key)
  /// - One for decrypting data we receive (from server encryption key)
  /// 
  /// Uses ARC4-drop1024: discards first 1024 bytes of keystream to
  /// increase security (standard practice with RC4).
  void init(Uint8List sessionKey) {
    if (sessionKey.length != 40) {
      throw ArgumentError('Session key must be 40 bytes');
    }

    // Derive encryption key (for packets we send TO server)
    // Server uses _serverDecryptionKey to decrypt what we send
    final encryptKey = hmacSha1(
      key: _serverDecryptionKey,
      data: sessionKey,
    );

    // Derive decryption key (for packets we receive FROM server)
    // Server uses _serverEncryptionKey to encrypt what it sends
    final decryptKey = hmacSha1(
      key: _serverEncryptionKey,
      data: sessionKey,
    );

    // Initialize ARC4 ciphers
    _serverEncrypt = ARC4();
    _serverEncrypt.init(encryptKey);

    _clientDecrypt = ARC4();
    _clientDecrypt.init(decryptKey);

    // Drop first 1024 bytes (ARC4-drop1024)
    final dropBuffer = Uint8List(1024);
    _serverEncrypt.updateData(dropBuffer);
    _clientDecrypt.updateData(dropBuffer);

    _initialized = true;
  }

  /// Decrypt received packet header
  /// 
  /// Modifies the data in-place.
  void decryptRecv(Uint8List data) {
    if (!_initialized) {
      throw StateError('AuthCrypt not initialized. Call init() first.');
    }
    _clientDecrypt.updateData(data);
  }

  /// Encrypt outgoing packet header
  /// 
  /// Modifies the data in-place.
  void encryptSend(Uint8List data) {
    if (!_initialized) {
      throw StateError('AuthCrypt not initialized. Call init() first.');
    }
    _serverEncrypt.updateData(data);
  }

  /// Check if encryption is initialized
  bool get isInitialized => _initialized;
}
