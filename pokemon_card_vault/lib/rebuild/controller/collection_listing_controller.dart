import 'dart:async';
import 'package:flutter/foundation.dart';
import '../model/cardex.dart';
import '../model/collection_listing.dart';
import '../service/collection_listing_service.dart';

class CollectionListingController extends ChangeNotifier {
  CollectionListingController(
      {required Stream<String?> Function() userIds,
      CollectionListingService? service})
      : _userIds = userIds,
        _service = service ?? CollectionListingService();
  final Stream<String?> Function() _userIds;
  final CollectionListingService _service;
  StreamSubscription<String?>? _session;
  String? _uid;
  int _generation = 0;
  bool _disposed = false;
  bool busy = false, uncertain = false;
  String? error;
  (CollectionListingTarget, CollectionDisposition, double?)? _pending;
  bool get signedIn => _uid != null;

  void start() {
    if (_disposed || _session != null) return;
    _session = _userIds()
        .distinct()
        .listen(_setUser, onError: (Object _) => _setUser(null));
  }

  void _setUser(String? uid) {
    if (_disposed || uid == _uid) return;
    ++_generation;
    _uid = uid;
    busy = uncertain = false;
    error = null;
    _pending = null;
    notifyListeners();
  }

  List<CollectionListingTarget> targets(
          CardCollection collection, String cardId, String? language) =>
      CollectionListingService.targets(collection, cardId, language);

  void clearFeedback() {
    if (_disposed || busy || uncertain) return;
    error = null;
    notifyListeners();
  }

  Future<bool> change(CardCollection collection, CollectionListingTarget target,
      CollectionDisposition desired, double? price) async {
    if (_disposed || busy || uncertain) return false;
    final uid = _uid;
    if (uid == null) {
      error = 'Accedi prima di modificare un listing.';
      notifyListeners();
      return false;
    }
    final current = targets(collection, target.item.card.id, null)
        .where((row) => row.key == target.key)
        .firstOrNull;
    if (current == null || current.item.quantity != target.item.quantity) {
      error = 'La copia non è più disponibile. Aggiorna la collezione.';
      notifyListeners();
      return false;
    }
    _pending = (current, desired, price);
    final generation = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _service.move(uid, current, desired, price);
      if (_disposed || generation != _generation) return false;
      _pending = null;
      return true;
    } on CollectionSwitchFailure catch (failure) {
      if (!_disposed && generation == _generation) {
        error = failure.message;
        uncertain = failure.uncertain;
        if (!uncertain) _pending = null;
      }
      return false;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        uncertain = true;
        error = 'Esito non confermato. Verifica prima di riprovare.';
      }
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> verifyPending() async {
    final pending = _pending;
    final uid = _uid;
    if (_disposed || busy || pending == null || uid == null) return false;
    final generation = ++_generation;
    busy = true;
    notifyListeners();
    try {
      final result =
          await _service.verify(uid, pending.$1, pending.$2, pending.$3);
      if (_disposed || generation != _generation) return false;
      if (result) {
        _pending = null;
        uncertain = false;
        error = null;
      } else {
        error =
            'Il cambio non risulta confermato. Aggiorna le carte o verifica su MyPokoin prima di ripubblicare.';
      }
      return result;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error =
            'Verifica non disponibile. Nessuna nuova pubblicazione inviata.';
      }
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _pending = null;
    unawaited(_session?.cancel());
    super.dispose();
  }
}
