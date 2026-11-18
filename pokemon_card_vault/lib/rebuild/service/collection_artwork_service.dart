import 'dart:async';
import '../cache/collection_artwork_cache.dart';
import '../constants/card_language_constants.dart';
import '../model/card.dart';
import '../provider/artwork_preferences_provider.dart';
import 'card_service.dart';

/// Public metadata and a local display preference, separate from owner stock.
class CollectionArtworkService {
  CollectionArtworkService(
      {CardService? cards,
      ArtworkPreferencesProvider? preferences,
      CollectionArtworkCache? cache})
      : _cards = cards ?? CardService(),
        _ownsCards = cards == null,
        _preferences = preferences ?? ArtworkPreferencesProvider(),
        _cache = cache ?? CollectionArtworkCache();
  final CollectionArtworkCache _cache;
  final CardService _cards;
  final bool _ownsCards;
  final ArtworkPreferencesProvider _preferences;
  Future<MarketplaceCard> fetchCard(String id) async {
    final cached = await _cache
        .read(id)
        .timeout(const Duration(milliseconds: 280), onTimeout: () => null);
    if (cached != null) return cached;
    final card = await _cards.fetchCard(id);
    unawaited(_cache.remember(card));
    return card;
  }

  Future<String> readLanguage() async {
    final code = (await _preferences.readLanguage())?.toUpperCase();
    return cardLanguageLabels.containsKey(code) ? code! : 'IT';
  }

  Future<void> writeLanguage(String code) => _preferences.writeLanguage(code);
  void dispose() {
    _cache.flush();
    if (_ownsCards) _cards.dispose();
  }
}
