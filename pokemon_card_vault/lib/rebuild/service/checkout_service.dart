import '../model/cart_item.dart';
import '../model/checkout_group.dart';

/// Derived projection only: original listing IDs remain in the persisted cart.
abstract final class CheckoutService {
  // Catalog display names do not expose a species ID. Remove only known trailing
  // card-mechanic suffixes; preserve regional/owner/multi-Pokemon names verbatim.
  static final _cardSuffix = RegExp(
      r'(?:\s+|-)(?:ex|gx|vmax|vstar|v-union|v|break|lv\.?\s*x|delta species|δ|☆|★)$',
      caseSensitive: false);

  static String _pileName(String name) {
    var result = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    while (true) {
      final next = result.replaceFirst(_cardSuffix, '').trim();
      if (next.isEmpty || next == result) return result;
      result = next;
    }
  }

  static List<CheckoutPile> piles(Iterable<CheckoutGroup> groups) {
    final byPokemon = <String, List<CheckoutGroup>>{};
    final names = <String, String>{};
    for (final group in groups) {
      if (group.offers.isEmpty) continue;
      final card = group.offers.first.card;
      final name = _pileName(card.name);
      final id = name.isEmpty ? 'card:${card.id}' : name.toLowerCase();
      names.putIfAbsent(id, () => name.isEmpty ? 'Carta #${card.id}' : name);
      byPokemon.putIfAbsent(id, () => []).add(group);
    }
    return List.unmodifiable(byPokemon.entries.map((entry) => CheckoutPile(
        id: entry.key, name: names[entry.key]!, groups: entry.value)));
  }

  static List<CheckoutGroup> group(Iterable<ListingCartItem> items) {
    final groups = <CheckoutGroupKey, List<ListingCartItem>>{};
    for (final item in items) {
      final key = CheckoutGroupKey(
          cardId: item.card.id,
          condition: item.listing.condition,
          language: item.listing.language,
          attributes: item.listing.attributes);
      groups.putIfAbsent(key, () => []).add(item);
    }
    return List.unmodifiable(
        groups.entries.map((e) => CheckoutGroup(e.key, e.value)));
  }
}
