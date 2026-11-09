import '../model/cardex.dart';
import '../model/collection_listing.dart';
import '../provider/collection_listing_provider.dart';
import 'card_ownership_service.dart';

class CollectionListingService {
  CollectionListingService({CollectionListingProvider? provider})
      : _provider = provider ?? CollectionListingProvider();
  final CollectionListingProvider _provider;

  static List<CollectionListingTarget> targets(
      CardCollection collection, String cardId, String? language) {
    if (collection.status != CollectionStatus.ready) return const [];
    const ownership = CardOwnershipService();
    return List.unmodifiable(collection.items
        .where((item) =>
            item.card.id == cardId &&
            item.id.isNotEmpty &&
            !item.isNft &&
            (language == null ||
                ownership.normalizeLanguage(item.language) == language))
        .map((item) => CollectionListingTarget(
            item: item,
            hasHolding: !item.fromListing ||
                collection.holdings.any((holding) =>
                    holding.card.id == item.card.id &&
                    (holding.id == item.sourceListingId ||
                        holding.listingId == item.id)))));
  }

  String _heldStatus(CollectionListingTarget target) =>
      target.hasHolding ? 'inactive' : 'paused';

  Future<bool> verify(String uid, CollectionListingTarget target,
      CollectionDisposition desired, double? price) async {
    final item = target.item;
    final rows = await _provider.listings(uid, item.card.id,
        id: item.fromListing ? item.id : null);
    final matches = rows
        .where((row) => item.fromListing
            ? row['id'] == item.id
            : row['sourceListingId'] == item.id)
        .toList();
    if (matches.length != 1) return false;
    final row = matches.single;
    if (desired == CollectionDisposition.collection) {
      return row['status'] == _heldStatus(target);
    }
    final actual = double.tryParse('${row['pricePkn']}');
    return row['status'] == 'active' &&
        (int.tryParse('${row['quantityAvailable']}') ?? 0) > 0 &&
        actual != null &&
        price != null &&
        (actual - price).abs() < .000001;
  }

  Future<void> move(String uid, CollectionListingTarget target,
      CollectionDisposition desired, double? price) async {
    final item = target.item;
    if (uid.isEmpty ||
        item.id.isEmpty ||
        item.isNft ||
        item.quantity <= 0 ||
        item.quantity > 99) {
      throw const CollectionSwitchFailure(
          'Questa copia non può essere spostata con questo comando.');
    }
    if (desired == CollectionDisposition.listing &&
        (price == null || !price.isFinite || price <= 0)) {
      throw const CollectionSwitchFailure(
          'Inserisci un prezzo PKN maggiore di zero.');
    }
    var wrote = false;
    var acknowledged = false;
    try {
      if (item.fromListing) {
        final current =
            await _provider.listings(uid, item.card.id, id: item.id);
        if (current.length != 1 ||
            current.single['id'] != item.id ||
            !const ['active', 'paused'].contains(current.single['status']) ||
            (int.tryParse('${current.single['quantityAvailable']}') ?? 0) <=
                0) {
          throw const CollectionSwitchFailure(
              'Il listing è cambiato. Aggiorna la collezione.');
        }
        wrote = true;
        await _provider.update(uid, item.id, {
          'status': desired == CollectionDisposition.listing
              ? 'active'
              : _heldStatus(target),
          if (desired == CollectionDisposition.listing) 'pricePkn': price,
        });
      } else {
        if (desired != CollectionDisposition.listing) return;
        final holding = await _provider.holding(uid, item.id);
        if (holding.card.id != item.card.id ||
            holding.quantity != item.quantity ||
            holding.language != item.language ||
            holding.isNft) {
          throw const CollectionSwitchFailure(
              'La copia è cambiata. Aggiorna la collezione.');
        }
        final existing = (await _provider.listings(uid, item.card.id))
            .where((row) => row['sourceListingId'] == item.id)
            .toList();
        if (existing.length > 1) {
          throw const CollectionSwitchFailure(
              'Più listing collegati: verifica la copia su MyPokoin.');
        }
        if (existing.isNotEmpty) {
          final row = existing.single;
          if (!const ['paused', 'inactive'].contains(row['status']) ||
              int.tryParse('${row['quantityAvailable']}') != holding.quantity) {
            throw const CollectionSwitchFailure(
                'Il listing collegato non è riattivabile.');
          }
          wrote = true;
          await _provider.update(uid, '${row['id']}', {
            'status': 'active',
            'pricePkn': price,
          });
        } else {
          final country = await _provider.country(uid);
          wrote = true;
          final row = await _provider.create(uid, {
            ...holding.attributes,
            'cardId': holding.card.id,
            'cardName': holding.card.name,
            'setName': holding.card.expansion,
            'collectorNumber': holding.card.number,
            'cardImageUrl': holding.card.imageUrl,
            'language': holding.language,
            'condition': holding.attributes['condition'] ?? 'NM',
            'pricePkn': price,
            'quantityAvailable': holding.quantity,
            'reverse': holding.reverse,
            'foilState': holding.reverse
                ? 'reverse'
                : holding.holo
                    ? 'holo'
                    : 'standard',
            'source': 'pokoin_collection',
            'sourceListingId': holding.id,
            'sellerCountry': country,
            'shipFromCountry': country,
            'targets': {'pokoin': true, 'cardtrader': false},
          });
          if (row['sellerUid'] != uid ||
              '${row['cardId']}' != item.card.id ||
              row['sourceListingId'] != item.id ||
              '${row['id'] ?? ''}'.isEmpty) {
            throw const CollectionSwitchFailure(
                'Listing non riconosciuto. Verifica l’esito.',
                uncertain: true);
          }
        }
      }
      acknowledged = true;
      if (!await verify(uid, target, desired, price)) {
        throw const CollectionSwitchFailure(
            'Il server non ha confermato il cambio. Verifica l’esito.',
            uncertain: true);
      }
    } on CollectionSwitchFailure catch (error) {
      if (acknowledged && !error.uncertain) {
        throw const CollectionSwitchFailure(
            'Cambio inviato, ma lettura di verifica non disponibile. Verifica l’esito.',
            uncertain: true);
      }
      rethrow;
    } catch (_) {
      throw CollectionSwitchFailure(
          'Non è stato possibile confermare il cambio.',
          uncertain: wrote);
    }
  }
}
