import 'package:flutter/foundation.dart';
import '../model/wardrobe.dart';
import '../service/wardrobe_service.dart';

class WardrobeController extends ChangeNotifier {
  WardrobeController({WardrobeService? service})
      : _service = service ?? WardrobeService();
  final WardrobeService _service;
  WardrobeSelection selection = const WardrobeSelection();
  bool ready = false, saving = false;
  String? feedback;
  bool _disposed = false, _started = false;
  int _revision = 0;

  Future<void> load() async {
    if (_disposed || _started) return;
    _started = true;
    final revision = _revision;
    try {
      final saved = await _service.load();
      if (_disposed || revision != _revision) return;
      selection = saved;
    } catch (_) {
      if (_disposed || revision != _revision) return;
      feedback = 'Non è stato possibile recuperare il guardaroba salvato.';
    } finally {
      if (!_disposed && revision == _revision) {
        ready = true;
        notifyListeners();
      }
    }
  }

  Future<bool> save(WardrobeSelection draft) async {
    if (_disposed || saving || !ready) return false;
    ++_revision;
    saving = true;
    feedback = null;
    notifyListeners();
    try {
      final next = _service.normalize(draft);
      await _service.save(next);
      if (_disposed) return false;
      selection = next;
      return true;
    } catch (_) {
      if (!_disposed) {
        feedback =
            'Salvataggio non riuscito. La scelta precedente è invariata. Riprova.';
      }
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
