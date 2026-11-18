import 'dart:async';
import 'dart:convert';
import '../model/cardex.dart';
import '../model/marketplace_home.dart';
import '../provider/cache_file_provider.dart';

/// Ordered opening previews from complete owner snapshots. They are never
/// ownership evidence, stock, a listing target or a cached asking price.
class CollectionPreviewCache {
  CollectionPreviewCache({CacheFileProvider? storage})
      : _storage = storage ??
            CacheFileProvider(fileName: 'collection-preview-v2.json');
  final CacheFileProvider _storage;
  static const retention = Duration(days: 7);
  static const maxPerScreen = 24;
  Map<String, dynamic> _record = {};
  String? _activeUid;
  Future<void>? _restore;
  Future<void> _operations = Future.value(), _writes = Future.value();
  Timer? _saveTimer;

  void activate(String? uid) {
    if (_activeUid == uid) return;
    _activeUid = uid;
    _saveTimer?.cancel();
  }

  Future<void> _load() => _restore ??= () async {
        try {
          final source = await _storage.read();
          if (source == null) return;
          final record = jsonDecode(source);
          if (record is Map<String, dynamic> && record['version'] == 2) {
            _record = record;
          }
        } catch (_) {
          // A preview must never delay/fail the authoritative owner requests.
        }
      }();

  List<MarketplaceCardPreview> _cards(String section) {
    final snapshot = _record[section];
    if (snapshot is! Map) return const [];
    final rows = snapshot['cards'];
    final saved = DateTime.tryParse('${snapshot['savedAt']}');
    final now = DateTime.now();
    if (rows is! List ||
        saved == null ||
        saved.isAfter(now) ||
        now.difference(saved) > retention) {
      return const [];
    }
    final result = <MarketplaceCardPreview>[];
    for (final row in rows.take(maxPerScreen)) {
      if (row is! Map<String, dynamic>) continue;
      final json = row;
      // Discard any dynamic fields even if a saved file has been modified.
      final card = MarketplaceCardPreview(
          id: '${json['id'] ?? ''}',
          name: '${json['name'] ?? ''}',
          expansion: '${json['set'] ?? ''}',
          number: '${json['number'] ?? ''}',
          imageUrl: '${json['imageUrl'] ?? ''}',
          fullImageUrl: '${json['heroImageUrl'] ?? ''}',
          canonicalPath: '${json['canonicalPath'] ?? ''}');
      if (RegExp(r'^[1-9]\d*$').hasMatch(card.id)) {
        result.add(card);
      }
    }
    return result;
  }

  Future<CardCollection?> read(String uid) async {
    await _operations;
    await _load();
    if (_activeUid != uid || _record['uid'] != uid) return null;
    final items = _cards('cardex');
    final listed = _cards('portfolio');
    if (items.isEmpty && listed.isEmpty) return null;
    return CardCollection(
        status: CollectionStatus.loading,
        ownerId: uid,
        fromCache: true,
        cachedCards: items,
        cachedListedCards: listed);
  }

  /// Save the exact canonical-print prefix used by each completed live view.
  /// Scrolling, widget rebuilds and the other screen never reorder this prefix.
  void synchronize(String uid,
      {List<MarketplaceCardPreview>? cardex,
      List<MarketplaceCardPreview>? portfolio}) {
    _operations = _operations.then((_) async {
      await _load();
      if (_activeUid != uid) return;
      if (_record['uid'] != uid) _record = {'version': 2, 'uid': uid};
      final savedAt = DateTime.now().toUtc().toIso8601String();
      for (final entry in {'cardex': cardex, 'portfolio': portfolio}.entries) {
        final cards = entry.value;
        if (cards == null) continue;
        _record[entry.key] = {
          'savedAt': savedAt,
          'cards': [
            for (final card in cards.take(maxPerScreen))
              {
                'id': card.id,
                'name': card.name,
                'set': card.expansion,
                'number': card.number,
                'imageUrl': card.imageUrl,
                'heroImageUrl': card.fullImageUrl,
                'canonicalPath': card.canonicalPath,
              }
          ],
        };
      }
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 250), flush);
    }).catchError((Object _) {});
  }

  void invalidate() {
    _saveTimer?.cancel();
    _operations = _operations.then((_) async {
      await _load();
      _record = {};
      flush();
    }).catchError((Object _) {});
  }

  void flush() {
    if (_restore == null) return;
    _saveTimer?.cancel();
    final source = jsonEncode(_record);
    _writes =
        _writes.then((_) => _storage.write(source)).catchError((Object _) {});
  }
}
