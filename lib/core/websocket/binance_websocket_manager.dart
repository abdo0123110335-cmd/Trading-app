import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:binance_spot_pro/core/api/binance_endpoints.dart';
import 'package:binance_spot_pro/core/utils/safe_logger.dart';

enum WsConnectionState { disconnected, connecting, connected, reconnecting }

/// Single, centrally-owned Binance market-data WebSocket connection.
///
/// This is intentionally a singleton-by-convention (constructed once and
/// injected via Riverpod) — individual widgets/screens must NEVER open
/// their own `WebSocketChannel.connect(...)`. Instead they call
/// [subscribe]/[unsubscribe] with the stream names they need (e.g.
/// `btcusdt@kline_1m`, `ethusdt@ticker`) and listen to [messages].
///
/// Responsibilities:
///   * Maintain exactly one combined-stream connection.
///   * Multiplex many symbol/stream subscriptions over that one socket.
///   * Reconnect with exponential backoff + jitter on drop.
///   * Re-subscribe everything automatically after a reconnect.
///   * Respond to server pings (handled transparently by the underlying
///     websocket implementation) and expose connection health.
class BinanceWebSocketManager {
  BinanceWebSocketManager();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;

  final Set<String> _activeStreams = <String>{};
  final StreamController<dynamic> _messageController =
      StreamController<dynamic>.broadcast();
  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();

  WsConnectionState _state = WsConnectionState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _manuallyDisconnected = true;

  /// Raw decoded JSON messages, keyed loosely by the `stream` field for
  /// combined-stream payloads. Consumers (market_data service) filter by
  /// symbol/stream themselves.
  Stream<dynamic> get messages => _messageController.stream;
  Stream<WsConnectionState> get connectionState => _stateController.stream;
  WsConnectionState get state => _state;
  Set<String> get activeStreams => Set.unmodifiable(_activeStreams);

  void _setState(WsConnectionState next) {
    _state = next;
    _stateController.add(next);
  }

  /// Opens the connection if not already open. Safe to call multiple times.
  Future<void> connect() async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }
    _manuallyDisconnected = false;
    _setState(WsConnectionState.connecting);
    await _openSocket();
  }

  Future<void> _openSocket() async {
    try {
      final streamsParam = _activeStreams.isEmpty
          ? 'btcusdt@ticker' // keep-alive placeholder stream if nothing subscribed yet
          : _activeStreams.join('/');
      final uri = Uri.parse(
        '${BinanceEndpoints.wsBase}${BinanceEndpoints.wsCombinedStreamPath}?streams=$streamsParam',
      );
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _reconnectAttempts = 0;
      _setState(WsConnectionState.connected);
      SafeLogger.i('WebSocket connected (${_activeStreams.length} streams)');

      _channelSub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      SafeLogger.w('WebSocket connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      _messageController.add(decoded);
    } catch (e) {
      SafeLogger.w('Failed to decode WS message: $e');
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    SafeLogger.w('WebSocket error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    if (_manuallyDisconnected) {
      _setState(WsConnectionState.disconnected);
      return;
    }
    SafeLogger.w('WebSocket closed unexpectedly, will reconnect');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manuallyDisconnected) return;
    _setState(WsConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    // Exponential backoff capped at 30s, with jitter to avoid thundering
    // herd if many app instances reconnect simultaneously.
    final baseDelay = min(30, pow(2, _reconnectAttempts).toInt());
    final jitterMs = Random().nextInt(500);
    final delay = Duration(seconds: baseDelay, milliseconds: jitterMs);
    SafeLogger.i(
      'Reconnecting WebSocket in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );
    _reconnectTimer = Timer(delay, () {
      if (!_manuallyDisconnected) {
        _openSocket();
      }
    });
  }

  /// Adds stream names (e.g. `btcusdt@kline_1m`) to the active subscription
  /// set. Because Binance combined streams are set via the connection URL,
  /// subscribing requires reopening the socket with the updated stream
  /// list — this is done efficiently with a short debounce so multiple
  /// widgets subscribing in the same frame only trigger one reconnect.
  Timer? _resubscribeDebounce;

  Future<void> subscribe(List<String> streamNames) async {
    final before = _activeStreams.length;
    _activeStreams.addAll(streamNames.map((s) => s.toLowerCase()));
    if (_activeStreams.length == before) return;
    _debouncedResubscribe();
  }

  Future<void> unsubscribe(List<String> streamNames) async {
    final before = _activeStreams.length;
    _activeStreams.removeAll(streamNames.map((s) => s.toLowerCase()));
    if (_activeStreams.length == before) return;
    _debouncedResubscribe();
  }

  void _debouncedResubscribe() {
    _resubscribeDebounce?.cancel();
    _resubscribeDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (_state == WsConnectionState.disconnected) return;
      await _channelSub?.cancel();
      await _channel?.sink.close();
      _setState(WsConnectionState.connecting);
      await _openSocket();
    });
  }

  Future<void> disconnect() async {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    await _channelSub?.cancel();
    await _channel?.sink.close();
    _setState(WsConnectionState.disconnected);
    SafeLogger.i('WebSocket disconnected');
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _resubscribeDebounce?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _stateController.close();
  }
}
