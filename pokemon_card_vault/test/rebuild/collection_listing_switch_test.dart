import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokoin/rebuild/controller/collection_listing_controller.dart';
import 'package:pokoin/rebuild/model/cardex.dart';
import 'package:pokoin/rebuild/model/collection_listing.dart';
import 'package:pokoin/rebuild/model/inventory_listing.dart';
import 'package:pokoin/rebuild/provider/collection_listing_provider.dart';
import 'package:pokoin/rebuild/service/collection_listing_service.dart';
import 'package:pokoin/rebuild/service/inventory_reconciliation_service.dart';
import 'package:pokoin/rebuild/presentation/cardex/component/collection_listing_sheet.dart';

const _holdingJson = <String, dynamic>{
  'id': 'held-1',
  'uid': 'owner',
  'cardId': '24',
  'cardName': 'Audino',
  'setName': 'Obsidian Flames',
  'collectorNumber': '173/197',
  'condition': 'NM',
  'language': 'EN',
  'quantity': 2,
  'reverse': true,
};

class _Backend {
  bool reject = false, loseResponse = false, wrongReadback = false;
  int writes = 0;
  Map<String, dynamic>? published;
  final rows = <Map<String, dynamic>>[];
  late final client = MockClient((request) async {
    expect(request.url.host, 'api.pokoin.com');
    expect(request.headers['Authorization'], 'Bearer test-token');
    http.Response json(Object value, [int status = 200]) =>
        http.Response(jsonEncode(value), status,
            headers: {'content-type': 'application/json; charset=utf-8'});
    if (request.method == 'GET') {
      if (request.url.path == '/api/marketplace-collection') {
        return json({
          'uid': 'owner',
          'items': [_holdingJson]
        });
      }
      if (request.url.path == '/api/marketplace-seller-settings') {
        return json({'shipFromCountry': 'IT'});
      }
      expect(request.url.queryParameters['sellerUid'], 'owner');
      final id = request.url.queryParameters['id'];
      return json({
        'listings': rows.where((row) => id == null || row['id'] == id).toList()
      });
    }
    writes++;
    if (reject) return json({'error': 'Not allowed'}, 403);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.method == 'POST') {
      published = body;
      final row = {
        ...body,
        'id': 'listing-1',
        'sellerUid': 'owner',
        'status': 'active',
        if (wrongReadback) 'pricePkn': 99.0
      };
      rows.add(row);
      if (loseResponse) {
        throw http.ClientException('Response lost after commit');
      }
      return json({...row, 'pricePkn': body['pricePkn']});
    }
    expect(request.method, 'PATCH');
    final row = rows
        .singleWhere((row) => row['id'] == request.url.queryParameters['id']);
    row.addAll(body);
    return json(row);
  });

  CollectionListingService get service => CollectionListingService(
      provider: CollectionListingProvider(
          client: client, token: (_) async => 'test-token'));
}

CardCollection _collection() {
  final holding = OwnedCard.fromJson(_holdingJson);
  return CardCollection(
      status: CollectionStatus.ready, items: [holding], holdings: [holding]);
}

Future<CollectionListingController> _controller(_Backend backend) async {
  final controller = CollectionListingController(
      userIds: () => Stream.value('owner'), service: backend.service);
  controller.start();
  await Future<void>.value();
  return controller;
}

Future<void> _open(WidgetTester tester, CollectionListingController controller,
    CardCollection collection, void Function(bool?) completed) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                  onPressed: () async {
                    final result = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CollectionListingSheet(
                            card: collection.cards.single,
                            collection: () => collection,
                            controller: controller,
                            language: 'EN'));
                    completed(result);
                  },
                  child: const Text('Apri'))))));
  await tester.tap(find.text('Apri'));
  await tester.pumpAndSettle();
  expect(find.byType(TextFormField), findsNothing);
  await tester.tap(find.text('Listing'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), '12,50');
  await tester.pump();
}

void main() {
  testWidgets(
      'Collection to Listing confirms only after matching server readback',
      (tester) async {
    final backend = _Backend();
    final controller = await _controller(backend);
    addTearDown(controller.dispose);
    addTearDown(backend.client.close);
    bool? result;
    await _open(tester, controller, _collection(), (value) => result = value);
    expect(backend.writes, 0);
    await tester.ensureVisible(find.text('Conferma Listing'));
    await tester.tap(find.text('Conferma Listing'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(backend.writes, 1);
    expect(backend.published, containsPair('sourceListingId', 'held-1'));
    expect(backend.published, containsPair('source', 'pokoin_collection'));
    expect(backend.published, containsPair('language', 'EN'));
    expect(backend.published, containsPair('reverse', true));
    expect(backend.published, containsPair('quantityAvailable', 2));
    expect(backend.rows.single['pricePkn'], 12.5);
  });

  testWidgets('rejected switch stays in the price dialog and reports failure',
      (tester) async {
    final backend = _Backend()..reject = true;
    final controller = await _controller(backend);
    addTearDown(controller.dispose);
    addTearDown(backend.client.close);
    bool? result;
    await _open(tester, controller, _collection(), (value) => result = value);
    await tester.ensureVisible(find.text('Conferma Listing'));
    await tester.tap(find.text('Conferma Listing'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.textContaining('HTTP 403'), findsOneWidget);
    expect(backend.rows, isEmpty);
    expect(controller.uncertain, isFalse);
  });

  for (final linked in [true, false]) {
    test(
        'Listing to Collection preserves owned copies (${linked ? 'linked holding' : 'native stock'})',
        () async {
      final backend = _Backend();
      addTearDown(backend.client.close);
      backend.rows.add({
        'id': 'listing-1',
        'cardId': '24',
        'sellerUid': 'owner',
        'status': 'active',
        'quantityAvailable': 2,
        'pricePkn': 12.5,
        'language': 'EN',
        'condition': 'NM',
        'sourceListingId': linked ? 'held-1' : ''
      });
      final inventory = InventoryListing.fromJson(backend.rows.single);
      final holding = OwnedCard.fromJson(_holdingJson);
      final collection = CardCollection(
          status: CollectionStatus.ready,
          items: [inventory.item],
          holdings: linked ? [holding] : []);
      final target =
          CollectionListingService.targets(collection, '24', 'EN').single;
      await backend.service
          .move('owner', target, CollectionDisposition.collection, null);
      final after = InventoryListing.fromJson(backend.rows.single);
      expect(after.status, linked ? 'inactive' : 'paused');
      expect(after.isListed, isFalse);
      final owned = const InventoryReconciliationService()
          .reconcile(linked ? [holding] : [], [after]);
      expect(owned.fold<int>(0, (sum, item) => sum + item.quantity), 2);
      expect(backend.writes, 1);
      final heldCollection = CardCollection(
          status: CollectionStatus.ready,
          items: owned,
          holdings: linked ? [holding] : []);
      final resume =
          CollectionListingService.targets(heldCollection, '24', 'EN').single;
      await backend.service
          .move('owner', resume, CollectionDisposition.listing, 14);
      expect(backend.rows, hasLength(1));
      expect(backend.rows.single['id'], 'listing-1');
      expect(backend.rows.single['status'], 'active');
      expect(backend.rows.single['pricePkn'], 14);
      expect(backend.rows.single['quantityAvailable'], 2);
      expect(backend.writes, 2);
    });
  }

  test(
      'lost write response requires read-only verification and never repeats publication',
      () async {
    final backend = _Backend()..loseResponse = true;
    final controller = await _controller(backend);
    addTearDown(controller.dispose);
    addTearDown(backend.client.close);
    final collection = _collection();
    final target = controller.targets(collection, '24', 'EN').single;
    expect(
        await controller.change(
            collection, target, CollectionDisposition.listing, 12.5),
        isFalse);
    expect(controller.uncertain, isTrue);
    expect(
        await controller.change(
            collection, target, CollectionDisposition.listing, 12.5),
        isFalse);
    expect(backend.writes, 1);
    expect(await controller.verifyPending(), isTrue);
    expect(controller.uncertain, isFalse);
    expect(backend.writes, 1);
  });

  test(
      'HTTP success with a mismatched persisted price is not a successful switch',
      () async {
    final backend = _Backend()..wrongReadback = true;
    final controller = await _controller(backend);
    addTearDown(controller.dispose);
    addTearDown(backend.client.close);
    final collection = _collection();
    final target = controller.targets(collection, '24', 'EN').single;
    expect(
        await controller.change(
            collection, target, CollectionDisposition.listing, 12.5),
        isFalse);
    expect(controller.uncertain, isTrue);
    expect(backend.writes, 1);
  });

  test('catalog-only cards and invalid prices cannot publish', () async {
    final backend = _Backend();
    final controller = await _controller(backend);
    addTearDown(controller.dispose);
    addTearDown(backend.client.close);
    final target = controller.targets(_collection(), '24', 'EN').single;
    expect(
        await controller.change(CardCollection(status: CollectionStatus.ready),
            target, CollectionDisposition.listing, 12.5),
        isFalse);
    await expectLater(
        backend.service.move('owner', target, CollectionDisposition.listing, 0),
        throwsA(isA<CollectionSwitchFailure>()));
    expect(backend.writes, 0);
  });
}
