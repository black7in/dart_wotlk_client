/// ARC4 (RC4) stream cipher implementation
/// 
/// This is a pure Dart implementation of the RC4 stream cipher algorithm.
/// Used for encrypting/decrypting WoW packet headers after authentication.

import 'dart:typed_data';

/// ARC4 (RC4) stream cipher
/// 
/// RC4 is a stream cipher that generates a pseudo-random stream of bytes
/// which are XORed with the plaintext to produce ciphertext (or vice versa).
class ARC4 {
  final List<int> _s = List<int>.filled(256, 0);
  int _i = 0;
  int _j = 0;
  bool _initialized = false;

  /// Initialize the cipher with a key
  /// 
  /// The key is used to initialize the internal state of the cipher.
  /// This follows the Key Scheduling Algorithm (KSA) of RC4.
  void init(Uint8List key) {
    if (key.isEmpty) {
      throw ArgumentError('Key cannot be empty');
    }

    // Initialize S-box
    for (int i = 0; i < 256; i++) {
      _s[i] = i;
    }

    // Key Scheduling Algorithm (KSA)
    int j = 0;
    for (int i = 0; i < 256; i++) {
      j = (j + _s[i] + key[i % key.length]) & 0xFF;
      _swap(i, j);
    }

    _i = 0;
    _j = 0;
    _initialized = true;
  }

  /// Process data with the cipher (encrypt or decrypt)
  /// 
  /// RC4 is symmetric - the same operation is used for both encryption
  /// and decryption. The data is modified in-place.
  void updateData(Uint8List data) {
    if (!_initialized) {
      throw StateError('Cipher not initialized. Call init() first.');
    }

    for (int n = 0; n < data.length; n++) {
      _i = (_i + 1) & 0xFF;
      _j = (_j + _s[_i]) & 0xFF;
      _swap(_i, _j);
      
      final k = _s[(_s[_i] + _s[_j]) & 0xFF];
      data[n] ^= k;
    }
  }

  /// Swap two elements in the S-box
  void _swap(int i, int j) {
    final temp = _s[i];
    _s[i] = _s[j];
    _s[j] = temp;
  }

  /// Check if the cipher is initialized
  bool get isInitialized => _initialized;
}
