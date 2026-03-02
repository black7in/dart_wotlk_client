/// SRP6 cryptographic functions for WoW authentication
import 'dart:typed_data';
import '../constants.dart';
import 'utils.dart';

/// Compute the SHA1 interleave algorithm as implemented in AzerothCore
/// 
/// This matches the server implementation in SRP6::SHA1Interleave
Uint8List sha1Interleave(Uint8List S) {
  final half = EPHEMERAL_KEY_LENGTH ~/ 2;
  final buf0 = Uint8List(half);
  final buf1 = Uint8List(half);
  
  // Split S into even and odd bytes
  for (int i = 0; i < half; ++i) {
    buf0[i] = S[2 * i + 0];
    buf1[i] = S[2 * i + 1];
  }

  // Find the first non-zero byte position
  int p = 0;
  while (p < EPHEMERAL_KEY_LENGTH && S[p] == 0) p++;
  
  // Ensure even position
  if ((p & 1) != 0) p++;
  p ~/= 2;

  // Hash the two halves starting from position p
  final hash0 = sha1Bytes(buf0.sublist(p));
  final hash1 = sha1Bytes(buf1.sublist(p));

  // Interleave the results
  final out = Uint8List(hash0.length * 2);
  for (int i = 0; i < hash0.length; ++i) {
    out[2 * i + 0] = hash0[i];
    out[2 * i + 1] = hash1[i];
  }
  return out;
}

/// Calculate the SRP6 password verifier
/// 
/// Returns g^x mod N where x = SHA1(salt || SHA1(username:password))
BigInt calculateVerifier(String username, String password, Uint8List salt) {
  final usernameUpper = username.toUpperCase();
  final passwordUpper = password.toUpperCase();
  
  // x = SHA1(s || SHA1(username || ':' || password))
  final inner = sha1Bytes('$usernameUpper:$passwordUpper'.codeUnits);
  final xBytes = sha1Bytes(concatUint8([salt, inner]));
  final x = bytesToBigIntLE(xBytes);
  
  // v = g^x mod N
  return g.modPow(x, N);
}

/// Calculate the SRP6 session key S
/// 
/// S = (B - k * g^x)^(a + u * x) mod N
BigInt calculateSessionSecret({
  required BigInt B,
  required BigInt a,
  required BigInt x,
  required BigInt u,
}) {
  // Calculate g^x
  final gx = g.modPow(x, N);
  
  // B - k * g^x (mod N)
  BigInt sub = (B - (k * gx)) % N;
  if (sub < BigInt.zero) sub += N;
  
  // Exponent: a + u * x
  final expo = a + (u * x);
  
  // S = (B - k*g^x)^(a + u*x) mod N
  return sub.modPow(expo, N);
}

/// Calculate NgHash = H(N) XOR H(g)
/// 
/// IMPORTANT: N and g are hashed in little-endian format
Uint8List calculateNgHash() {
  final NH = sha1Bytes(bigIntToBytesLE(N, 32));
  final gH = sha1Bytes(bigIntToBytesLE(g, 1));
  
  final NgHash = Uint8List(20);
  for (int i = 0; i < 20; ++i) {
    NgHash[i] = NH[i] ^ gH[i];
  }
  return NgHash;
}

/// Calculate the client proof M
/// 
/// M = SHA1(H(N) xor H(g), H(I), s, A, B, K)
Uint8List calculateClientProof({
  required String username,
  required Uint8List salt,
  required Uint8List A,
  required Uint8List B,
  required Uint8List K,
}) {
  final NgHash = calculateNgHash();
  final I_hash = sha1Bytes(username.toUpperCase().codeUnits);
  
  return sha1Bytes(concatUint8([NgHash, I_hash, salt, A, B, K]));
}

/// SRP6 computation result
class SRP6Result {
  /// Client's ephemeral public key A
  final Uint8List A;
  
  /// Client's ephemeral private key a
  final BigInt a;
  
  /// The scrambling parameter u = SHA1(A || B)
  final BigInt u;
  
  /// The session secret S
  final BigInt S;
  
  /// The session key K = SHA1Interleave(S)
  final Uint8List K;
  
  /// The client proof M
  final Uint8List M;

  SRP6Result({
    required this.A,
    required this.a,
    required this.u,
    required this.S,
    required this.K,
    required this.M,
  });
}

/// Perform complete SRP6 client-side calculation
SRP6Result computeSRP6({
  required String username,
  required String password,
  required Uint8List salt,
  required Uint8List B,
  BigInt? customA, // For testing
}) {
  final usernameUpper = username.toUpperCase();
  final passwordUpper = password.toUpperCase();
  
  // Calculate x = SHA1(s || SHA1(username:password))
  final inner = sha1Bytes('$usernameUpper:$passwordUpper'.codeUnits);
  final xBytes = sha1Bytes(concatUint8([salt, inner]));
  final x = bytesToBigIntLE(xBytes);
  
  // Generate random a and calculate A = g^a mod N
  final a = customA ?? randomBigInt(32);
  final A_big = g.modPow(a, N);
  final A_bytes = bigIntToBytesLE(A_big, EPHEMERAL_KEY_LENGTH);
  
  // Parse server's B
  final B_big = bytesToBigIntLE(B);
  
  // Calculate u = SHA1(A || B) - both must be 32-byte padded
  final A_padded = pad32(A_bytes, EPHEMERAL_KEY_LENGTH);
  final B_padded = pad32(B, EPHEMERAL_KEY_LENGTH);
  final uBytes = sha1Bytes(concatUint8([A_padded, B_padded]));
  final u = bytesToBigIntLE(uBytes);
  
  // Calculate session secret S
  final S_big = calculateSessionSecret(B: B_big, a: a, x: x, u: u);
  final S_bytes = bigIntToBytesLE(S_big, EPHEMERAL_KEY_LENGTH);
  
  // Derive session key K
  final K = sha1Interleave(S_bytes);
  
  // Calculate client proof M
  final M = calculateClientProof(
    username: usernameUpper,
    salt: salt,
    A: A_bytes,
    B: B,
    K: K,
  );
  
  return SRP6Result(
    A: A_bytes,
    a: a,
    u: u,
    S: S_big,
    K: K,
    M: M,
  );
}
