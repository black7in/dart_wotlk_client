import '../packets/server/login_verify_world.dart';

/// Result of world login.
class WorldLoginResult {
  final bool success;
  final String message;
  final int? errorCode;
  final LoginVerifyWorldPacket? verifyWorld;

  WorldLoginResult({
    required this.success,
    required this.message,
    this.errorCode,
    this.verifyWorld,
  });

  factory WorldLoginResult.success({
    required String message,
    LoginVerifyWorldPacket? verifyWorld,
  }) {
    return WorldLoginResult(
      success: true,
      message: message,
      verifyWorld: verifyWorld,
    );
  }

  factory WorldLoginResult.failure({
    required int errorCode,
    required String message,
  }) {
    return WorldLoginResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}
