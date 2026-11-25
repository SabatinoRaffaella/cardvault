import 'dart:async';
import 'dart:convert';
import '../model/card.dart';
import '../provider/cache_file_provider.dart';

/// Public scan manifests for artwork actually requested by visible cards.
/// Prices, listings, ownership and failed requests are never stored here.
class CollectionArtworkCache {
  CollectionArtworkCache({CacheFileProvider? storage})
      : _storage = storage ??
            CacheFileProvider(fileName: 'collection-artwork-v1.json');
  final CacheFileProvider _storage;
  static const retention = Duration(days: 7);
  static const maxEntries = 200;
  final _entries = <String, Map<String, dynamic>>{};
  Future<void>? _restore;
  Future<void> _writes = Future.value();
  Timer? _saveTimer;

  Future<void> _load() => _restore ??= () async {
        try {
          final source = await _storage.read();
          if (source == null) return;
          final record = jsonDecode(source);
          if (record is! Map ||
              record['version'] != 1 ||
              record['cards'] is! List) {
            return;
          }
          final now = DateTime.now();
          for (final row in (record['cards'] as List).take(maxEntries)) {
            if (row is! Map<String, dynamic>) continue;
            final id = '${row['id'] ?? ''}';
            final saved = DateTime.tryParse('${row['savedAt']}');
            final manifest = row['langScans'];
            if (!RegExp(r'^[1-9]\d*$').hasMatch(id) ||
                saved == null ||
                saved.isAfter(now) ||
                manifest is! String ||
                manifest.length > 2000) {
              continue;
            }
            _entries[id] = row;
          }
        } catch (_) {
          // Optional cache: corrupt/unavailable storage falls back to the API.
        }
      }();

  Future<MarketplaceCard?> read(String id, {bool allowExpired = false}) async {
    await _load();
    final row = _entries.remove(id);
    if (row == null) return null;
    final saved = DateTime.tryParse('${row['savedAt']}');
    if (saved == null ||
        (!allowExpired && DateTime.now().difference(saved) > retention)) {
      _entries[id] = row;
      return null;
    }
    _entries[id] = row;
    _scheduleSave();
    // Deliberately only the public language manifest, never a cached card price.
    return MarketplaceCard(
        id: id,
        name: '',
        expansion: '',
        number: '',
        imageUrl: '',
        languageScans: '${row['langScans']}');
  }

  Future<void> remember(MarketplaceCard card) async {
    if (!RegExp(r'^[1-9]\d*$').hasMatch(card.id) ||
        card.languageScans.length > 2000) {
      return;
    }
    await _load();
    _entries.remove(card.id);
    _entries[card.id] = {
      'id': card.id,
      'langScans': card.languageScans,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    };
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), flush);
  }

  Future<void> flush() async {
    if (_restore == null) return;
    await _restore;
    _saveTimer?.cancel();
    final source =
        jsonEncode({'version': 1, 'cards': _entries.values.toList()});
    _writes =
        _writes.then((_) => _storage.write(source)).catchError((Object _) {});
    await _writes;
  }
}
