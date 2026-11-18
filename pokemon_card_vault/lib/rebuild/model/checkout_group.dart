import 'dart:convert';
import 'cart_item.dart';

/// Value key: seller and price belong to each offer, not to the visual group.
class CheckoutGroupKey {
  CheckoutGroupKey(
      {required this.cardId,
      required String condition,
      required String language,
      required Iterable<String> attributes})
      : condition = condition.trim().toUpperCase(),
        language = language.trim().toUpperCase(),
        variant = jsonEncode((attributes
            .map((v) => v.trim().toLowerCase())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort()));

  final String cardId, condition, language, variant;

  @override
  bool operator ==(Object other) =>
      other is CheckoutGroupKey &&
      cardId == other.cardId &&
      condition == other.condition &&
      language == other.language &&
      variant == other.variant;
  @override
  int get hashCode => Object.hash(cardId, condition, language, variant);
}

class CheckoutGroup {
  CheckoutGroup(this.key, Iterable<ListingCartItem> offers)
      : offers = List.unmodifiable(offers);
  final CheckoutGroupKey key;
  final List<ListingCartItem> offers;
  int get quantity => offers.fold(0, (sum, item) => sum + item.quantity);
  double get totalPkn => offers.fold(0, (sum, item) => sum + item.totalPkn);
}

/// A visual family of cards; its precise purchasable groups stay distinct.
class CheckoutPile {
  CheckoutPile(
      {required this.id,
      required this.name,
      required Iterable<CheckoutGroup> groups})
      : groups = List.unmodifiable(groups);
  final String id, name;
  final List<CheckoutGroup> groups;
  int get quantity => groups.fold(0, (sum, group) => sum + group.quantity);
}
