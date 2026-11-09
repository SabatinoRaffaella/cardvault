import 'dart:async';
import 'package:flutter/foundation.dart';
import '../model/portfolio_history.dart';
import '../service/portfolio_service.dart';

class PortfolioController extends ChangeNotifier {
  PortfolioController(
      {required Stream<String?> Function() userIds, PortfolioService? service})
      : _userIds = userIds,
        _service = service ?? PortfolioService();
  final Stream<String?> Function() _userIds;
  final PortfolioService _service;
  StreamSubscription<String?>? _subscription;
  String? _uid;
  int _generation = 0;
  bool _disposed = false, _wanted = false, _loaded = false;
  bool loading = false, failed = false;
  List<PortfolioHistoryPoint> history = const [];
  PortfolioPeriod period = PortfolioPeriod.month;
  bool get signedIn => _uid != null;
  List<PortfolioHistoryPoint> get visibleHistory =>
      _service.inPeriod(history, period);

  void start() {
    if (_disposed || _subscription != null) return;
    _subscription =
        _userIds().distinct().listen(_setUser, onError: (Object error) {
      _setUser(null);
    });
  }

  void _setUser(String? uid) {
    if (_disposed || _uid == uid) return;
    ++_generation;
    _uid = uid;
    history = const [];
    loading = failed = _loaded = false;
    period = PortfolioPeriod.month;
    notifyListeners();
    if (_wanted && uid != null) unawaited(loadHistory());
  }

  Future<void> loadHistory({bool forceRefresh = false}) async {
    if (_disposed) return;
    _wanted = true;
    start();
    final uid = _uid;
    if (uid == null || loading || (_loaded && !forceRefresh)) return;
    final request = ++_generation;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final result = await _service.loadHistory(uid);
      if (_disposed || request != _generation) return;
      history = result;
      _loaded = true;
    } catch (_) {
      if (!_disposed && request == _generation) failed = true;
    } finally {
      if (!_disposed && request == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void selectPeriod(PortfolioPeriod value) {
    if (_disposed || period == value) return;
    period = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    history = const [];
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
