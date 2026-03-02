import '../packets/server/char_enum.dart';

/// Result of authentication + character enumeration.
class WorldConnectionResult {
  final bool success;
  final String message;
  final int? errorCode;
  final List<CharacterData>? characters;

  WorldConnectionResult({
    required this.success,
    required this.message,
    this.errorCode,
    this.characters,
  });

  factory WorldConnectionResult.successResult({
    required String message,
    required List<CharacterData> characters,
  }) {
    return WorldConnectionResult(
      success: true,
      message: message,
      characters: characters,
    );
  }

  factory WorldConnectionResult.failure(int errorCode, String message) {
    return WorldConnectionResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}
