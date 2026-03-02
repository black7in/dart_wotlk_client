import 'dart:typed_data';

/// Platform-agnostic transport interface.
///
/// Implementations provide the raw byte I/O layer so the world client
/// remains independent of dart:io (TCP) or any other network backend.
abstract class ITransport {
  String get host;
  int get port;

  /// Establish the connection.
  Future<void> connect();

  /// Send raw bytes to the remote end.
  void send(Uint8List data);

  /// Stream of inbound byte chunks.  Must be a broadcast stream.
  Stream<Uint8List> get dataStream;

  /// Close the connection.
  Future<void> close();

  bool get isConnected;
}
