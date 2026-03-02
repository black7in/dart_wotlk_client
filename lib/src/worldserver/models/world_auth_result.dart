/// Result of world server authentication.
class WorldAuthResult {
  final bool success;
  final String message;
  final int? errorCode;

  WorldAuthResult({
    required this.success,
    required this.message,
    this.errorCode,
  });

  factory WorldAuthResult.successResult(String message) {
    return WorldAuthResult(success: true, message: message);
  }

  factory WorldAuthResult.failure(int errorCode, String message) {
    return WorldAuthResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}
