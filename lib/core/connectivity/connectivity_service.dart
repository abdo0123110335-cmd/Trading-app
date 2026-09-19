import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Tracks whether the device currently has *some* network connectivity
/// (Wi-Fi or mobile data reachable at the OS level — not a guarantee
/// Binance itself is reachable, but a good, cheap first signal).
///
/// Used for two things per the spec's Offline Mode requirement:
///   1. Showing an "OFFLINE" banner and falling back to last-known local
///      data instead of blank/error screens.
///   2. Blocking Live Trading order placement outright when connectivity
///      is anything other than confirmed-online — an order should never
///      be attempted while the connection state is uncertain.
class ConnectivityService {
  ConnectivityService() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      _isOnline = _resultIndicatesOnline(results);
      _controller.add(_isOnline);
    });
    Connectivity().checkConnectivity().then((results) {
      _isOnline = _resultIndicatesOnline(results);
      _controller.add(_isOnline);
    });
  }

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<bool> get onlineStream => _controller.stream;

  bool _resultIndicatesOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
