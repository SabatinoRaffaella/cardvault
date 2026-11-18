import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokoin/rebuild/controller/cardex_controller.dart';
import 'package:pokoin/rebuild/presentation/cardex/cardex_screen.dart';
import 'package:pokoin/rebuild/presentation/cardex/atomics/album_card_caption.dart';
import 'package:pokoin/rebuild/presentation/cardex/atomics/cardex_artwork_window.dart';
import 'package:pokoin/rebuild/presentation/portfolio/portfolio_screen.dart';
import 'package:pokoin/rebuild/presentation/shared/atomics/card_language_flag.dart';
import 'package:pokoin/rebuild/presentation/shared/atomics/card_ownership_frame.dart';
import 'package:pokoin/rebuild/presentation/shared/atomics/collection_quantity_badge.dart';
import 'package:pokoin/rebuild/presentation/shared/atomics/marketplace_thumbnail.dart';
import 'package:pokoin/rebuild/style/cardex_style.dart';
import 'card_ownership_test.dart' as fixtures;

void main() {
  for (final portfolio in [false, true]) {
    for (final size in [(390.0, 1.0), (320.0, 2.0), (900.0, 1.0)]) {
      testWidgets(
          '${portfolio ? "Portfolio" : "Cardex"} controls do not cover scan at $size',
          (tester) async {
        tester.view.physicalSize = Size(size.$1, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = CardexController()..collection = fixtures.owned();
        addTearDown(controller.dispose);
        var opened = 0;
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(size.$1, 1600),
                    textScaler: TextScaler.linear(size.$2)),
                child: Scaffold(
                    body: portfolio
                        ? PortfolioScreen(
                            controller: controller, onOpen: (_) => opened++)
                        : CardexScreen(
                            controller: controller,
                            onOpen: (_) => opened++)))));
        await tester.pumpAndSettle();
        final flag = tester.getRect(find.byType(CardLanguageFlag));
        final quantity = tester.getRect(find.byType(CollectionQuantityBadge));
        final frame = tester.getRect(find.byType(CardOwnershipFrame));
        final image = tester.getRect(find
            .byType(portfolio ? MarketplaceThumbnail : CardexArtworkWindow));
        expect(flag.bottom, lessThanOrEqualTo(image.top));
        expect(quantity.bottom, lessThanOrEqualTo(image.top));
        // Controls are incorporated into the top outline, not a separate row.
        if (portfolio) {
          expect(flag.top, lessThan(frame.top));
          expect(flag.bottom, greaterThan(frame.top));
        } else {
          expect(flag.bottom, lessThanOrEqualTo(frame.top));
        }
        expect(quantity.overlaps(flag), isFalse);
        expect(
            tester.getSize(find.byType(CardLanguageBadge)), const Size(48, 48));
        final caption = tester.getRect(find.byType(AlbumCardCaption));
        if (portfolio) {
          final scan = tester.getRect(find.byType(MarketplaceThumbnail));
          expect(caption.top, greaterThanOrEqualTo(frame.bottom));
          expect(scan.width / scan.height,
              closeTo(CardexStyle.cardAspectRatio, .001));
          expect(scan.top, greaterThanOrEqualTo(frame.top));
          expect(scan.bottom, lessThanOrEqualTo(frame.bottom));
        } else {
          final artwork = tester.getRect(find.byType(CardexArtworkWindow));
          expect(artwork.top, closeTo(frame.top + 1, .001));
          expect(artwork.bottom, closeTo(frame.bottom - 1, .001));
          // The actual illustration, not only its viewport, touches the frame.
          final scan = tester.getRect(find.byType(MarketplaceThumbnail));
          expect(scan.top + scan.height * .12, closeTo(artwork.top, .001));
          expect(
              scan.bottom - scan.height * .54, closeTo(artwork.bottom, .001));
          expect(caption.bottom, closeTo(artwork.bottom, .001));
          expect(caption.top, greaterThanOrEqualTo(artwork.top));
        }
        expect(
            find.descendant(
                of: find.byType(AlbumCardCaption),
                matching: find.byType(DecoratedBox)),
            findsNothing);
        await tester.tap(find.byType(CardLanguageBadge));
        await tester.pumpAndSettle();
        expect(opened, 0);
        expect(
            tester.widget<PopupMenuItem<String>>(fixtures.option('FR')).enabled,
            isFalse);
        await tester.ensureVisible(fixtures.option('EN'));
        await tester.tap(fixtures.option('EN'));
        await tester.pumpAndSettle();
        expect(controller.ownershipFor('24').selectedLanguage, 'EN');
        expect(find.text('×3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
