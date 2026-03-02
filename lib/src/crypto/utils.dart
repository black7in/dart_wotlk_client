/// Cryptographic utility functions for WoW authentication
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Compute SHA1 hash of bytes
Uint8List sha1Bytes(List<int> bytes) =>
    Uint8List.fromList(sha1.convert(bytes).bytes);

/// Compute HMAC-SHA1
/// 
/// Returns the HMAC-SHA1 digest of the data using the given key.
Uint8List hmacSha1({required Uint8List key, required Uint8List data}) {
  final hmac = Hmac(sha1, key);
  return Uint8List.fromList(hmac.convert(data).bytes);
}

/// Convert bytes to BigInt using little-endian format (WoW protocol standard)
BigInt bytesToBigIntLE(Uint8List b) {
  BigInt res = BigInt.zero;
  // Read in reverse (little-endian)
  for (int i = b.length - 1; i >= 0; i--) {
    res = (res << 8) | BigInt.from(b[i] & 0xff);
  }
  return res;
}

/// Convert bytes to BigInt using big-endian format (for hash computations)
BigInt bytesToBigIntBE(Uint8List b) {
  BigInt res = BigInt.zero;
  for (final byte in b) {
    res = (res << 8) | BigInt.from(byte & 0xff);
  }
  return res;
}

/// Convert BigInt to bytes using little-endian format (WoW protocol standard)
/// 
/// WoW uses LITTLE-ENDIAN format for network protocol values!
Uint8List bigIntToBytesLE(BigInt v, int length) {
  var tmp = <int>[];
  BigInt t = v;
  while (t > BigInt.zero) {
    tmp.add((t & BigInt.from(0xff)).toInt());
    t = t >> 8;
  }
  // Pad to exact length
  while (tmp.length < length) {
    tmp.add(0);
  }
  // Already in little-endian order
  return Uint8List.fromList(tmp.take(length).toList());
}

/// Convert BigInt to bytes using big-endian format (for hash inputs)
Uint8List bigIntToBytesBE(BigInt v, int length) {
  var tmp = <int>[];
  BigInt t = v;
  while (t > BigInt.zero) {
    tmp.add((t & BigInt.from(0xff)).toInt());
    t = t >> 8;
  }
  while (tmp.length < length) {
    tmp.add(0);
  }
  return Uint8List.fromList(tmp.reversed.take(length).toList());
}

/// Concatenate multiple Uint8List arrays
Uint8List concatUint8(List<Uint8List> arrays) {
  final out = BytesBuilder();
  for (final a in arrays) {
    out.add(a);
  }
  return out.toBytes();
}

/// Ensure a 32-byte left-padded representation (big-endian padding)
Uint8List pad32(Uint8List inBytes, int targetLength) {
  if (inBytes.length == targetLength) return inBytes;
  if (inBytes.length > targetLength) {
    // keep right-most (least-significant) bytes
    return Uint8List.fromList(
        inBytes.sublist(inBytes.length - targetLength));
  }
  final out = Uint8List(targetLength);
  out.setRange(targetLength - inBytes.length, targetLength, inBytes);
  return out;
}

/// Generate a random BigInt of specified byte length
BigInt randomBigInt(int bytes) {
  final rnd = Random.secure();
  final list = List<int>.generate(bytes, (_) => rnd.nextInt(256));
  return bytesToBigIntLE(Uint8List.fromList(list));
}
