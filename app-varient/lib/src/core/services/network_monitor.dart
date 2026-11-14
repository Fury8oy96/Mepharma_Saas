import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

enum NetworkState {
  online,
  offline,
  syncing,
}

class NetworkMonitor extends ChangeNotifier {
  NetworkMonitor({
    required String baseUrl,
    this.pingInterval = const Duration(seconds: 6),
    bool enabled = true,
  })  : _baseUrl = baseUrl,
        _enabled = enabled {
    if (_enabled) {
      _startPeriodicProbe();
    }
  }

  String _baseUrl;
  String get baseUrl => _baseUrl;
  final Duration pingInterval;
  bool _enabled;
  bool get enabled => _enabled;

  bool _isDisposed = false;

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (_enabled) {
      _startPeriodicProbe();
    } else {
      _probeTimer?.cancel();
      _probeTimer = null;
      _consecutiveFailures = 0;
      _lastError = null;
      if (_state != NetworkState.offline) {
        _state = NetworkState.offline;
      }
      notifyListeners();
    }
  }

  void updateBaseUrl(String newUrl) {
    if (_baseUrl != newUrl) {
      _baseUrl = newUrl;
      if (_enabled) {
        checkConnectivity();
      }
    }
  }

  NetworkState _state = NetworkState.online;
  NetworkState get state => _state;
  bool get isOnline => _state == NetworkState.online || _state == NetworkState.syncing;
  bool get isOffline => _state == NetworkState.offline;
  bool get isSyncing => _state == NetworkState.syncing;

  Timer? _probeTimer;
  final _connectionStreamController = StreamController<NetworkState>.broadcast();
  Stream<NetworkState> get onStatusChange => _connectionStreamController.stream;

  DateTime? _lastOnlineTime;
  DateTime? get lastOnlineTime => _lastOnlineTime;

  int _consecutiveFailures = 0;
  int get consecutiveFailures => _consecutiveFailures;

  /// Most recent error message from a failed sync or API call.
  String? _lastError;
  String? get lastError => _lastError;

  void _startPeriodicProbe() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(pingInterval, (_) => checkConnectivity());
    // Initial check
    checkConnectivity();
  }

  /// Actively probes the health endpoint
  Future<bool> checkConnectivity() async {
    if (!_enabled) {
      return false;
    }
    try {
      var cleanBase = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
      if (cleanBase.contains('.localhost')) {
        cleanBase = cleanBase.replaceAll(RegExp(r'//[^/:]+\.localhost'), '//localhost');
      }
      final path = cleanBase.endsWith('/api') ? '/health' : '/api/health';
      final uri = Uri.parse('$cleanBase$path');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _reportOnline();
        return true;
      } else {
        _reportOffline('Health check returned status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _reportOffline(e.toString());
      return false;
    }
  }

  static bool isTransportFailure(Object error) {
    if (error is TimeoutException) return true;
    if (error is ApiException) {
      final code = error.statusCode;
      if (code == null) return true;
      if (code >= 502 && code <= 504) return true;
      if (code >= 400 && code < 500) return false;
    }
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('connection reset') ||
        str.contains('network is unreachable') ||
        str.contains('timeout') ||
        str.contains('timed out') ||
        str.contains('failed host lookup') ||
        str.contains('clientexception') ||
        str.contains('handshake failed') ||
        str.contains('broken pipe') ||
        str.contains('connection closed') ||
        str.contains('disconnect') ||
        str.contains('network error') ||
        str.contains('offline');
  }

  /// Call this when any API request fails with network error to immediately drop to offline mode
  void reportFailure(Object error) {
    if (!isTransportFailure(error)) {
      return;
    }
    _consecutiveFailures++;
    _lastError = error.toString();
    if (_state != NetworkState.offline) {
      _state = NetworkState.offline;
      if (!_connectionStreamController.isClosed) {
        _connectionStreamController.add(NetworkState.offline);
      }
      notifyListeners();
    }
  }

  /// Call this when any API request succeeds
  void reportSuccess() {
    _lastError = null;
    _reportOnline();
  }

  void setSyncing(bool syncing) {
    if (syncing) {
      if (_state != NetworkState.syncing) {
        _state = NetworkState.syncing;
        if (!_connectionStreamController.isClosed) {
          _connectionStreamController.add(NetworkState.syncing);
        }
        notifyListeners();
      }
    } else {
      // Sync completed: directly return to online state and notify listeners
      if (_state == NetworkState.syncing) {
        _state = NetworkState.online;
        _lastOnlineTime = DateTime.now();
        if (!_connectionStreamController.isClosed) {
          _connectionStreamController.add(NetworkState.online);
        }
        notifyListeners();
      }
    }
  }

  void _reportOnline() {
    _consecutiveFailures = 0;
    _lastOnlineTime = DateTime.now();
    if (_state != NetworkState.online && _state != NetworkState.syncing) {
      _state = NetworkState.online;
      if (!_connectionStreamController.isClosed) {
        _connectionStreamController.add(NetworkState.online);
      }
      notifyListeners();
    }
  }

  void _reportOffline(String reason) {
    _consecutiveFailures++;
    _lastError = reason;
    if (_state != NetworkState.offline) {
      _state = NetworkState.offline;
      if (!_connectionStreamController.isClosed) {
        _connectionStreamController.add(NetworkState.offline);
      }
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _probeTimer?.cancel();
    _connectionStreamController.close();
    super.dispose();
  }
}
