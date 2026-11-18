import 'marketplace_home.dart';

enum CollectionStatus { loading, guest, ready, unavailable }

enum CardexFilter { all, owned, missing }

/// Una copia/variante posseduta. Nessun accesso a Firebase nel modello.
class OwnedCard {
  const OwnedCard(
      {required this.card,
      required this.quantity,
      this.id = '',
      this.listingId = '',
      this.sourceListingId = '',
      this.language = '',
      this.fromListing = false,
      this.listingStatus = '',
      this.isNft = false,
      this.attributes = const {},
      this.holo = false,
      this.reverse = false});

  factory OwnedCard.fromJson(Map<String, dynamic> json,
          {bool fromListing = false}) =>
      OwnedCard(
        fromListing: fromListing,
        listingStatus:
            fromListing ? '${json['status'] ?? ''}'.trim().toLowerCase() : '',
        isNft: json['ownershipType'] == 'nft' ||
            json['fulfillmentMode'] == 'nft_only' ||
            json['nftStatus'] == 'owned',
        attributes: Map.unmodifiable({
          for (final key in const [
            'condition',
            'signed',
            'firstEdition',
            'graded',
            'gradingCompany',
            'grade',
            'certificationId',
            'sealed',
            'altered',
            'shippingAvailable',
            'location',
            'sellerComment',
            'foilState',
            'variantState',
          ])
            if (json.containsKey(key)) key: json[key]
        }),
        id: '${json['id'] ?? ''}'.trim(),
        listingId: '${json['listingId'] ?? ''}'.trim(),
        sourceListingId: '${json['sourceListingId'] ?? ''}'.trim(),
        card: MarketplaceCardPreview(
          id: '${json['cardId'] ?? json['blueprintId'] ?? ''}'.trim(),
          name: '${json['cardName'] ?? json['name'] ?? ''}',
          expansion: '${json['setName'] ?? ''}',
          number: '${json['collectorNumber'] ?? ''}',
          imageUrl: '${json['cardImageUrl'] ?? ''}',
          pricePkn: switch (double.tryParse('${json['pricePkn'] ?? ''}')) {
            final double price when price.isFinite && price > 0 => price,
            _ => null,
          },
          canonicalPath: '${json['canonicalPath'] ?? ''}',
        ),
        quantity: num.tryParse('${json['quantity'] ?? 0}')?.toInt() ?? 0,
        language: '${json['language'] ?? ''}',
        holo: json['holo'] == true,
        reverse: json['reverse'] == true,
      );

  final MarketplaceCardPreview card;
  final String id, listingId, sourceListingId;
  final int quantity;
  final String language;
  final bool fromListing, isNft;
  final String listingStatus;
  final Map<String, dynamic> attributes;
  final bool holo, reverse;
}

class CardCollection {
  CardCollection(
      {required this.status,
      this.ownerId = '',
      this.fromCache = false,
      List<MarketplaceCardPreview> cachedCards = const [],
      List<MarketplaceCardPreview> cachedListedCards = const [],
      CollectionStatus? listingsStatus,
      List<OwnedCard> items = const [],
      List<OwnedCard> holdings = const [],
      List<OwnedCard> listedItems = const []})
      : listingsStatus = listingsStatus ?? status,
        cachedCards = List.unmodifiable(cachedCards),
        cachedListedCards = List.unmodifiable(cachedListedCards),
        holdings = List.unmodifiable(holdings),
        items = List.unmodifiable(items
            .where((item) => item.quantity > 0 && item.card.id.isNotEmpty)),
        listedItems = List.unmodifiable(listedItems
            .where((item) => item.quantity > 0 && item.card.id.isNotEmpty));
  final CollectionStatus status;
  final String ownerId;

  /// Artwork-only saved preview; never evidence of current ownership/listings.
  final bool fromCache;
  final List<MarketplaceCardPreview> cachedCards, cachedListedCards;
  // Owner listings are complete independently of Held reconciliation.
  final CollectionStatus listingsStatus;
  final List<OwnedCard> items;
  final List<OwnedCard> holdings;

  /// Solo stock attivo proveniente dagli owner listing, mai dai record Held.
  final List<OwnedCard> listedItems;

  /// Solo ID canonici Pokoin: nomi simili non rendono posseduta un'altra stampa.
  int quantityFor(String id) => items
      .where((item) => item.card.id == id)
      .fold(0, (sum, item) => sum + item.quantity);
  bool owns(String id) => quantityFor(id) > 0;
  late final int copies = items.fold(0, (sum, item) => sum + item.quantity);
  late final List<MarketplaceCardPreview> cards = fromCache
      ? cachedCards
      : List.unmodifiable({
          for (final item in items) item.card.id: item.card,
        }.values);
}

class CardexPage {
  CardexPage(
      {required this.expansion,
      required List<MarketplaceCardPreview> cards,
      required this.offset,
      required this.hasMore,
      required this.total})
      : cards = List.unmodifiable(cards);
  final MarketplaceExpansion expansion;
  final List<MarketplaceCardPreview> cards;
  final int offset, total;
  final bool hasMore;
}
