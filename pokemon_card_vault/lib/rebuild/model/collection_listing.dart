import 'cardex.dart';

enum CollectionDisposition { collection, listing }

class CollectionListingTarget {
  const CollectionListingTarget({required this.item, required this.hasHolding});
  final OwnedCard item;
  final bool hasHolding;
  String get key => '${item.fromListing ? 'listing' : 'holding'}:${item.id}';
  bool get listed => item.fromListing && item.listingStatus == 'active';
}

class CollectionSwitchFailure implements Exception {
  const CollectionSwitchFailure(this.message, {this.uncertain = false});
  final String message;
  final bool uncertain;
}
