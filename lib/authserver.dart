/// WoW 3.3.5a Authentication Client Library for AzerothCore
///
/// This library provides a complete SRP6 authentication implementation
/// for connecting to World of Warcraft 3.3.5a (WotLK) authentication servers.
library authserver;

// Export public API
export 'src/constants.dart';
export 'src/authserver/auth_client.dart';
export 'src/authserver/packets.dart';
export 'src/crypto/srp6.dart';
export 'src/crypto/utils.dart';
