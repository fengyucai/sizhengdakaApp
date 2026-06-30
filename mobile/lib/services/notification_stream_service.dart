import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_service.dart';

class NotificationStreamService {
  NotificationStreamService._();

  static final NotificationStreamService instance = NotificationStreamService._();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  CancelToken? _cancelToken;
  StreamSubscription<List<int>>? _subscription;
  bool _started = false;
  bool _disposed = false;
  Timer? _reconnectTimer;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    await _connect();
  }

  Future<void> stop() async {
    _started = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelToken?.cancel('notification stream stopped');
    _cancelToken = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _controller.close();
  }

  Future<void> _connect() async {
    if (!_started || _disposed) return;
    _cancelToken?.cancel('notification stream reconnect');
    _cancelToken = CancelToken();

    try {
      final response = await ApiService.dio.get<ResponseBody>(
        '/notifications/stream',
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          receiveTimeout: Duration.zero,
        ),
        cancelToken: _cancelToken,
      );
      final body = response.data;
      if (body == null) {
        _scheduleReconnect();
        return;
      }
      final buffer = StringBuffer();
      _subscription = body.stream.listen(
        (chunk) {
          buffer.write(utf8.decode(chunk, allowMalformed: true));
          _drainBuffer(buffer);
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _drainBuffer(StringBuffer buffer) {
    final text = buffer.toString().replaceAll('\r\n', '\n');
    final events = text.split('\n\n');
    buffer.clear();
    if (!text.endsWith('\n\n') && events.isNotEmpty) {
      buffer.write(events.removeLast());
    }
    for (final eventText in events) {
      final event = _parseEvent(eventText);
      if (event != null && !_controller.isClosed) {
        _controller.add(event);
      }
    }
  }

  Map<String, dynamic>? _parseEvent(String raw) {
    final dataLines = raw
        .split('\n')
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trimLeft())
        .where((line) => line.isNotEmpty)
        .toList();
    if (dataLines.isEmpty) return null;
    try {
      final decoded = jsonDecode(dataLines.join('\n'));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void _scheduleReconnect() {
    if (!_started || _disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }
}
