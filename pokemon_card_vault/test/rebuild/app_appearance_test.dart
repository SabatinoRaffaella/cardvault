import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pokoin/rebuild/main_mobile_prototype.dart';
import 'package:pokoin/rebuild/model/app_appearance.dart';
import 'package:pokoin/rebuild/model/account.dart';
import 'package:pokoin/rebuild/model/demo_catalog.dart';
import 'package:pokoin/rebuild/service/account_service.dart';
import 'package:pokoin/rebuild/service/card_service.dart';
import 'package:pokoin/rebuild/service/cart_service.dart';
import 'package:pokoin/rebuild/presentation/shared/component/app_appearance_scope.dart';
import 'package:pokoin/rebuild/presentation/marketplace/marketplace_screen.dart';
import 'fixtures/account_fixtures.dart';
import 'fixtures/cart_fixtures.dart';

Finder customCardex() => find.byWidgetPredicate((widget) =>
    widget is Image &&
    widget.image is AssetImage &&
    (widget.image as AssetImage).assetName == 'assets/icons/Cardex.png');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'initial app screen keeps Default and changes appearance without resetting navigation',
      (tester) async {
    final provider = FakeAccountProvider(guest: true);
    final cart =
        CartService(local: MemoryCartLocal(), remote: MemoryCartRemote());
    var requests = 0;
    final cards = CardService(client: MockClient((_) async {
      requests++;
      return http.Response('{}', 404);
    }));
    await tester.pumpWidget(MobileMarketplacePrototypeApp(
        showDiscovery: false,
        accountService: AccountService(provider: provider),
        cartService: cart,
        cardService: cards));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AppAppearanceScope>(find.byType(AppAppearanceScope))
            .notifier!
            .appearance,
        AppAppearance.defaultTheme);
    expect(find.byIcon(Icons.menu_book_outlined), findsWidgets);
    final before = tester
        .widget<MarketplaceScreen>(find.byType(MarketplaceScreen))
        .controller;
    before.cart.addCard(demoCards.first);
    before.selectTab(4);
    await tester.pumpAndSettle();
    expect(find.text('Modalità Ospite'), findsOneWidget);
    await tester.tap(find.text('Tema dell’app'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-dungeon_crawler')));
    await tester.pumpAndSettle();
    final after = tester
        .widget<MarketplaceScreen>(find.byType(MarketplaceScreen))
        .controller;
    expect(after, same(before));
    expect(after.selectedTab, 4);
    expect(after.cart.itemCount, 1);
    expect(after.account.session.status, AccountStatus.guest);
    expect(customCardex(), findsNWidgets(2));
    expect(requests, 0);
    // An already-open route stays open when the theme changes globally.
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Keep this route')))));
    await tester.pumpAndSettle();
    final appearance = tester
        .widget<AppAppearanceScope>(find.byType(AppAppearanceScope))
        .notifier!;
    await appearance.select(AppAppearance.defaultTheme);
    await tester.pumpAndSettle();
    expect(find.text('Keep this route'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsOneWidget);
    expect(customCardex(), findsNothing);
    expect(before.cart.itemCount, 1);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    cart.dispose();
    cards.dispose();
    await provider.close();
  });
}
