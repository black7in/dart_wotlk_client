/// Authentication protocol opcodes and constants for WoW 3.3.5a

// Protocol opcodes
const int AUTH_LOGON_CHALLENGE = 0x00;
const int AUTH_LOGON_PROOF = 0x01;
const int AUTH_RECONNECT_CHALLENGE = 0x02;
const int AUTH_RECONNECT_PROOF = 0x03;
const int REALM_LIST = 0x10;

// Authentication result codes
const int WOW_SUCCESS = 0x00;

/// Error 0x04 - Used for BOTH unknown account AND incorrect password
/// This is by design for security reasons - the server doesn't want to reveal
/// whether an account exists or not.
const int WOW_FAIL_UNKNOWN_ACCOUNT = 0x04;

const int WOW_FAIL_INCORRECT_PASSWORD = 0x05;
const int WOW_FAIL_ALREADY_ONLINE = 0x06;
const int WOW_FAIL_NO_TIME = 0x07;
const int WOW_FAIL_DB_BUSY = 0x08;
const int WOW_FAIL_VERSION_INVALID = 0x09;
const int WOW_FAIL_VERSION_UPDATE = 0x0A;
const int WOW_FAIL_INVALID_SERVER = 0x0B;
const int WOW_FAIL_SUSPENDED = 0x0C;
const int WOW_FAIL_FAIL_NOACCESS = 0x0D;
const int WOW_FAIL_SUCCESS_SURVEY = 0x0E;
const int WOW_FAIL_PARENTCONTROL = 0x0F;
const int WOW_FAIL_LOCKED_ENFORCED = 0x10;

// SRP6 parameters (from AzerothCore)
/// The prime modulus N for SRP6 calculations (256-bit)
final BigInt N = BigInt.parse(
    '894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7',
    radix: 16);

/// The generator g for SRP6 calculations
final BigInt g = BigInt.from(7);

/// The multiplier k for SRP6 calculations
final BigInt k = BigInt.from(3);

/// Length of ephemeral keys (A, B, S) in bytes
const int EPHEMERAL_KEY_LENGTH = 32;

/// Length of salt in bytes
const int SALT_LENGTH = 32;

/// WoW 3.3.5a client build number
const int WOW_BUILD = 12340;

/// Client version
const int VERSION_MAJOR = 3;
const int VERSION_MINOR = 3;
const int VERSION_PATCH = 5;

/// Platform identifier
const String PLATFORM = 'x86';

/// OS identifier (reversed for network protocol)
const String OS_REVERSED = 'niW'; // "Win" reversed

/// Locale identifier (reversed for network protocol)
const String LOCALE_REVERSED = 'SUne'; // "enUS" reversed
