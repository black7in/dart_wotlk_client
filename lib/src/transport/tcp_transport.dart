import 'dart:io';
import 'dart:typed_data';

import 'i_transport.dart';

/// dart:io TCP implementation of [ITransport].
class TcpTransport implements ITransport {
  @override
  final String host;
  @override
  final int port;

  Socket? _socket;
  Stream<Uint8List>? _broadcastStream;

  TcpTransport({required this.host, required this.port});

  @override
  bool get isConnected => _socket != null;

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _broadcastStream = _socket!
        .map((data) => Uint8List.fromList(data))
        .asBroadcastStream();
  }

  @override
  void send(Uint8List data) {
    _socket!.add(data);
  }

  /// Flush any buffered bytes to the socket.
  Future<void> flush() => _socket!.flush();

  @override
  Stream<Uint8List> get dataStream {
    assert(_broadcastStream != null, 'Call connect() before accessing dataStream');
    return _broadcastStream!;
  }

  @override
  Future<void> close() async {
    await _socket?.close();
    _socket = null;
    _broadcastStream = null;
  }
}
