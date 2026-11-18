import '../model/cardex.dart';
import '../model/collection_listing.dart';
import '../model/inventory_listing.dart';
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

  bool _sameVariant(OwnedCard holding, Map<String, dynamic> row) {
    final listing = InventoryListing.fromJson(row).item;
    const ownership = CardOwnershipService();
    String text(Object? value) => '${value ?? ''}'.trim().toUpperCase();
    if (listing.isNft ||
        listing.card.id != holding.card.id ||
        ownership.normalizeLanguage(listing.language) !=
            ownership.normalizeLanguage(holding.language) ||
        text(listing.attributes['condition'] ?? 'NM') !=
            text(holding.attributes['condition'] ?? 'NM') ||
        listing.holo != holding.holo ||
        listing.reverse != holding.reverse) {
      return false;
    }
    for (final key in const [
      'signed',
      'firstEdition',
      'sealed',
      'graded',
      'altered'
    ]) {
      if ((listing.attributes[key] == true) !=
          (holding.attributes[key] == true)) {
        return false;
      }
    }
    for (final key in const [
      'variantState',
      'gradingCompany',
      'grade',
      'certificationId'
    ]) {
      if (text(listing.attributes[key]) != text(holding.attributes[key])) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic>? _linkedListing(
      OwnedCard holding, List<Map<String, dynamic>> rows) {
    final linked = rows.where((row) =>
        row['sourceListingId'] == holding.id ||
        (holding.listingId.isNotEmpty && row['id'] == holding.listingId));
    int quantity(Map<String, dynamic> row) =>
        int.tryParse('${row['quantityAvailable']}') ?? 0;
    // Repeated List/Hold cycles on MyPokoin can leave multiple inactive rows.
    // Only live stock can conflict; never choose between two live listings.
    final active = linked
        .where((row) => row['status'] == 'active' && quantity(row) > 0)
        .toList();
    if (active.isNotEmpty) {
      if (active.length != 1 ||
          !_sameVariant(holding, active.single) ||
          quantity(active.single) != holding.quantity) {
        throw const CollectionSwitchFailure(
            'I listing attivi collegati non identificano una sola copia della stessa lingua e variante. Verifica su MyPokoin.');
      }
      return active.single;
    }
    final reusable = linked
        .where((row) =>
            const ['paused', 'inactive'].contains(row['status']) &&
            quantity(row) == holding.quantity &&
            _sameVariant(holding, row))
        .toList();
    if (reusable.isEmpty) return null;
    final explicit =
        reusable.where((row) => row['id'] == holding.listingId).firstOrNull;
    if (explicit != null) return explicit;
    DateTime date(Map<String, dynamic> row, String key) =>
        DateTime.tryParse('${row[key]}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    reusable.sort((a, b) {
      final updated = date(b, 'updatedAt').compareTo(date(a, 'updatedAt'));
      if (updated != 0) return updated;
      final created = date(b, 'createdAt').compareTo(date(a, 'createdAt'));
      return created != 0 ? created : '${a['id']}'.compareTo('${b['id']}');
    });
    return reusable.first;
  }

  Future<bool> verify(String uid, CollectionListingTarget target,
      CollectionDisposition desired, double? price) async {
    final item = target.item;
    final rows = await _provider.listings(uid, item.card.id,
        id: item.fromListing ? item.id : null);
    final row = item.fromListing
        ? rows.where((row) => row['id'] == item.id).singleOrNull
        : _linkedListing(item, rows);
    if (row == null ||
        !_sameVariant(item, row) ||
        int.tryParse('${row['quantityAvailable']}') != item.quantity) {
      return false;
    }
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
            !_sameVariant(item, current.single) ||
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
        final row = _linkedListing(
            holding, await _provider.listings(uid, item.card.id));
        if (row != null) {
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
