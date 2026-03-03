import 'dart:async';
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
  StreamController<Uint8List>? _controller;
  Stream<Uint8List>? _broadcastStream;

  TcpTransport({required this.host, required this.port});

  @override
  bool get isConnected => _socket != null;

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    // Use a broadcast StreamController so there is always exactly ONE
    // underlying socket subscription.  asBroadcastStream() cancels the
    // source when the last listener leaves, which permanently kills a
    // single-subscription socket stream.  With a controller the socket
    // stays alive across subscription gaps (auth → login → keepAlive).
    _controller = StreamController<Uint8List>.broadcast();
    _socket!.listen(
      (data) => _controller!.add(Uint8List.fromList(data)),
      onError: _controller!.addError,
      onDone: _controller!.close,
    );
    _broadcastStream = _controller!.stream;
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
    await _controller?.close();
    _socket = null;
    _controller = null;
    _broadcastStream = null;
  }
}
