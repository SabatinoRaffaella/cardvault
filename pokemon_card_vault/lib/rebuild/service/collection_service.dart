import 'dart:async';
import '../cache/collection_preview_cache.dart';
import '../model/cardex.dart';
import '../provider/collection_provider.dart';
import '../provider/inventory_provider.dart';
import '../model/inventory_listing.dart';
import 'inventory_reconciliation_service.dart';

/// Coordina sessione e collezione senza dipendere da Riverpod o widget legacy.
class CollectionService {
  CollectionService(
      {CollectionProvider? provider,
      InventoryProvider? inventory,
      CollectionPreviewCache? previews})
      : _provider = provider ?? CollectionProvider(),
        _inventory =
            inventory ?? (provider == null ? InventoryProvider() : null),
        _previews = previews ?? CollectionPreviewCache();
  final CollectionPreviewCache _previews;
  bool _skipPreviewOnce = false;
  final CollectionProvider _provider;
  final InventoryProvider? _inventory;

  void invalidatePreview() {
    _skipPreviewOnce = true;
    _previews.invalidate();
  }

  Stream<CardCollection> watch() {
    late StreamController<CardCollection> output;
    StreamSubscription<String?>? session;
    StreamSubscription<List<OwnedCard>>? items;
    StreamSubscription<InventorySnapshot>? inventory;
    var version = 0;
    var cancelled = false;
    void emit(CardCollection collection) {
      if (!cancelled) output.add(collection);
    }

    void unavailable() =>
        emit(CardCollection(status: CollectionStatus.unavailable));
    Future<void> changeUser(String? uid) async {
      final request = ++version;
      _previews.activate(uid);
      final previous = items;
      items = null;
      unawaited(inventory?.cancel());
      inventory = null;
      emit(CardCollection(
          ownerId: uid ?? '',
          status:
              uid == null ? CollectionStatus.guest : CollectionStatus.loading));
      await previous?.cancel();
      if (cancelled || request != version || uid == null) return;
      List<OwnedCard>? holdings;
      List<InventoryListing>? listings = _inventory == null ? const [] : null;
      var inventoryComplete = _inventory == null;
      var holdingsFailed = false, listingsFailed = false;
      CardCollection? savedPreview;

      void publish() {
        if (request != version || cancelled) return;
        if (listings == null && !holdingsFailed && !listingsFailed) return;
        final listedItems = listingsFailed
            ? const <OwnedCard>[]
            : (listings ?? const <InventoryListing>[])
                .where((row) => row.isListed)
                .map((row) => row.item)
                .toList();
        final listingsStatus = listingsFailed
            ? CollectionStatus.unavailable
            : inventoryComplete
                ? CollectionStatus.ready
                : CollectionStatus.loading;
        if (listingsStatus == CollectionStatus.ready) {
          _previews.synchronize(uid,
              portfolio: CardCollection(
                      status: CollectionStatus.ready, items: listedItems)
                  .cards);
        }
        if (holdingsFailed || listingsFailed) {
          // Cardex needs both sources; Portfolio needs only validated listings.
          emit(CardCollection(
              ownerId: uid,
              status: CollectionStatus.unavailable,
              listingsStatus: listingsStatus,
              listedItems: listedItems));
        } else if (inventoryComplete && holdings != null) {
          final owned = const InventoryReconciliationService()
              .reconcile(holdings!, listings!);
          final complete = CardCollection(
              ownerId: uid,
              status: CollectionStatus.ready,
              listingsStatus: listingsStatus,
              holdings: holdings!,
              listedItems: listedItems,
              items: owned);
          _previews.synchronize(uid, cardex: complete.cards);
          emit(complete);
        } else {
          // Show proven listed cards early, never unmatched mirrored holdings.
          // Quantities/absence stay unknown until both complete sources reconcile.
          final preview = (listings ?? const <InventoryListing>[])
              .where((row) => row.isOwned)
              .map((row) => row.item)
              .toList();
          emit(CardCollection(
              ownerId: uid,
              status: CollectionStatus.loading,
              // Keep the opening Cardex snapshot until Held reconciliation is
              // complete, rather than briefly replacing it with only listings.
              fromCache: savedPreview?.cachedCards.isNotEmpty == true,
              cachedCards: savedPreview?.cachedCards ?? const [],
              cachedListedCards: savedPreview?.cachedListedCards ?? const [],
              listingsStatus: listingsStatus,
              items: preview,
              listedItems: listedItems));
        }
      }

      final skipPreview = _skipPreviewOnce;
      _skipPreviewOnce = false;
      if (_inventory != null && !skipPreview) {
        unawaited(_previews.read(uid).then((preview) {
          if (!cancelled &&
              request == version &&
              listings == null &&
              !holdingsFailed &&
              !listingsFailed &&
              preview != null) {
            savedPreview = preview;
            emit(preview);
          }
        }).catchError((Object _) {}));
      }

      if (_inventory != null) {
        inventory = _inventory.watchItems(uid).listen((page) {
          listings = page.items;
          inventoryComplete = page.complete;
          publish();
        }, onError: (Object error, StackTrace stack) {
          listingsFailed = true;
          publish();
        });
      }
      items = _provider.watchItems(uid).listen((rows) {
        holdings = rows;
        publish();
      }, onError: (Object error, StackTrace stack) {
        holdingsFailed = true;
        publish();
      });
    }

    output = StreamController<CardCollection>(onListen: () {
      emit(CardCollection(status: CollectionStatus.loading));
      session = _provider.watchUserId().listen((uid) {
        unawaited(changeUser(uid).catchError((Object error) {
          unavailable();
        }));
      }, onError: (Object error, StackTrace stack) {
        ++version;
        unawaited(items?.cancel());
        unawaited(inventory?.cancel());
        items = null;
        inventory = null;
        unavailable();
      });
    }, onCancel: () async {
      cancelled = true;
      ++version;
      await session?.cancel();
      await items?.cancel();
      await inventory?.cancel();
      _previews.flush();
    });
    return output.stream;
  }
}
