import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokoin/rebuild/controller/cart_controller.dart';
import 'package:pokoin/rebuild/controller/checkout_controller.dart';
import 'package:pokoin/rebuild/model/card.dart';
import 'package:pokoin/rebuild/model/cart_item.dart';
import 'package:pokoin/rebuild/model/listing.dart';
import 'package:pokoin/rebuild/presentation/checkout/checkout_screen.dart';
import 'package:pokoin/rebuild/presentation/shared/component/marketplace_cart_sheet.dart';
import 'package:pokoin/rebuild/service/cart_service.dart';
import 'package:pokoin/rebuild/service/checkout_service.dart';
import 'package:pokoin/rebuild/presentation/checkout/atomics/checkout_bundle_gesture.dart';
import 'fixtures/cart_fixtures.dart';

const _card = MarketplaceCard(
    id: '24',
    name: 'Pikachu Ex',
    expansion: 'Set A',
    number: '12/100',
    imageUrl: '');
MarketplaceListing _offer(String id,
        {String seller = 'Venditore A',
        double price = 5,
        String condition = 'MP',
        String language = 'IT',
        List<String> attributes = const []}) =>
    MarketplaceListing(
        id: id,
        cardId: '24',
        sellerName: seller,
        country: 'IT',
        condition: condition,
        language: language,
        pricePkn: price,
        stock: 10,
        attributes: attributes);

void main() {
  test('grouping keeps equal-price sellers distinct and normalizes variants',
      () {
    final first = ListingCartItem(
        card: _card,
        listing: _offer('a', attributes: ['Reverse', 'Firmata']),
        quantity: 2);
    final second = ListingCartItem(
        card: _card,
        listing: _offer('b',
            seller: 'Venditore B',
            attributes: ['firmata', 'reverse', 'reverse']),
        quantity: 1);
    final standard =
        ListingCartItem(card: _card, listing: _offer('c'), quantity: 1);
    final nm = ListingCartItem(
        card: _card, listing: _offer('d', condition: 'NM'), quantity: 1);
    final english = ListingCartItem(
        card: _card, listing: _offer('e', language: 'EN'), quantity: 1);
    final groups =
        CheckoutService.group([first, second, standard, nm, english]);
    expect(groups, hasLength(4));
    expect(groups.first.offers.map((item) => item.listing.id), ['a', 'b']);
    expect(groups.first.quantity, 3);
    expect(groups.first.totalPkn, 15);
    expect(() => groups.first.offers.clear(), throwsUnsupportedError);
  });

  test('selection and selector use listing IDs across edits and removals', () {
    final service = CartService();
    final cart = CartController(service: service);
    final checkout = CheckoutController(cart);
    addTearDown(checkout.dispose);
    addTearDown(cart.dispose);
    addTearDown(service.dispose);
    cart.addListing(_card, _offer('a'));
    cart.addListing(_card, _offer('a'));
    cart.addListing(_card, _offer('b', seller: 'Venditore B', price: 7));
    final group = checkout.groups.single;
    expect(checkout.selectedTotalPkn, 17);
    checkout.selectOffer(group, 'b');
    checkout.setSelectedQuantity('a', 1);
    expect(checkout.selectedCount, 2);
    expect(checkout.selectedTotalPkn, 12);
    expect(checkout.selectionFor(group), isNull);
    expect(service.listingQuantity('a'), 2);
    checkout.removeOffer('a');
    expect(checkout.activeOffer(checkout.groups.single).listing.id, 'b');
    expect(checkout.selectedTotalPkn, 7);
    expect(checkout.selectedItems.single.listing.id, 'b');
    checkout.selectAll(false);
    cart.addListing(_card, _offer('b', seller: 'Venditore B', price: 7));
    expect(checkout.selectedCount, 0);
    checkout.selectGroup(checkout.groups.single, true);
    checkout.removeCopy('b');
    expect(checkout.selectedCount, 1);
    expect(service.listingQuantity('b'), 1);
    cart.clear();
    expect(checkout.groups, isEmpty);
    expect(checkout.selectedCount, 0);
    expect(checkout.selectedTotalPkn, 0);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'checkout opens, browses sellers and removes the correct offer at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = CartService();
      final cart = CartController(service: service);
      addTearDown(cart.dispose);
      addTearDown(service.dispose);
      cart.addListing(_card, _offer('a'));
      cart.addListing(_card, _offer('b', seller: 'Venditore B'));
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showMarketplaceCartSheet(
                          context: context, controller: cart),
                      child: const Text('Apri carrello'))))));
      await tester.tap(find.text('Apri carrello'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Checkout');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(find.byType(MarketplaceCartSheet), findsNothing);
      final expand = find.text('Vedi offerte e venditori');
      await tester.ensureVisible(expand);
      await tester.pumpAndSettle();
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(find.text('Venditore A'), findsOneWidget);
      expect(find.text('Offerta 1 di 2'), findsOneWidget);
      final next = find.byTooltip('Offerta successiva');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Venditore B'), findsOneWidget);
      final remove = find.text('Rimuovi una copia');
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(service.listingQuantity('b'), 0);
      expect(service.listingQuantity('a'), 1);
      expect(find.text('Venditore A'), findsOneWidget);
      expect(find.text('Offerta 1 di 1'), findsOneWidget);
      await tester.tap(find.text('Annulla ultima rimozione'));
      await tester.pumpAndSettle();
      expect(service.listingQuantity('b'), 1);
      expect(find.text('Venditore B'), findsOneWidget);
      await tester.tap(find.byTooltip('Chiudi dettagli'));
      await tester.pumpAndSettle();
      expect(find.text('Venditore B'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test(
      'copy Undo preserves selection, last-row metadata and the account boundary',
      () async {
    final row = ListingCartItem(
        card: _card,
        listing: _offer('a'),
        quantity: 2,
        storedData: const {'legacyNote': 'keep me'});
    final local = MemoryCartLocal()..saved[null] = CartSnapshot(items: [row]);
    final service = CartService(local: local);
    await service.loadForUser(null);
    final cart = CartController(service: service);
    final checkout = CheckoutController(cart);
    addTearDown(() {
      checkout.dispose();
      cart.dispose();
      service.dispose();
    });
    checkout.setSelectedQuantity('a', 1);
    expect(checkout.removeCopy('a'), isTrue);
    expect(checkout.undoRemoval(), isTrue);
    expect(service.listingQuantity('a'), 2);
    expect(checkout.selectedQuantity('a'), 1);
    checkout.removeCopy('a');
    checkout.removeCopy('a');
    expect(service.listingItems, isEmpty);
    expect(checkout.undoRemoval(), isTrue);
    await settleCart(service);
    expect(service.listingQuantity('a'), 1);
    expect(local.saved[null]!.items.single.storedData['legacyNote'], 'keep me');
    checkout.removeCopy('a');
    await service.loadForUser('other-account');
    expect(checkout.canUndo, isFalse);
    expect(checkout.undoRemoval(), isFalse);
    expect(service.listingItems, isEmpty);
    await settleCart(service);
  });

  testWidgets(
      'holding then dragging chooses one axis; a short drag does nothing',
      (tester) async {
    var removed = 0, next = 0, previous = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: CheckoutBundleGesture(
                    targetId: 'a',
                    onRemove: () => removed++,
                    onNext: () => next++,
                    onPrevious: () => previous++,
                    child: const SizedBox(
                        key: ValueKey('gesture-surface'),
                        width: 200,
                        height: 200))))));
    Future<void> drag(Offset delta) async {
      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('gesture-surface'))));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(delta);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await drag(const Offset(-110, 0));
    expect(next, 1);
    expect(removed, 0);
    await drag(const Offset(0, -110));
    expect(removed, 1);
    expect(next, 1);
    await drag(const Offset(110, 0));
    expect(previous, 1);
    await drag(const Offset(0, -35));
    expect(removed, 1);
    expect(tester.takeException(), isNull);
  });
}
