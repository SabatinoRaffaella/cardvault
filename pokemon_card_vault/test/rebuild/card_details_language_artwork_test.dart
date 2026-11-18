import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokoin/rebuild/model/card.dart';
import 'package:pokoin/rebuild/model/cardex.dart';
import 'package:pokoin/rebuild/model/card_language_artwork.dart';
import 'package:pokoin/rebuild/presentation/card_details/component/card_details_artwork.dart';
import 'package:pokoin/rebuild/presentation/shared/atomics/card_language_flag.dart';
import 'package:pokoin/rebuild/presentation/shared/atomics/collection_quantity_badge.dart';
import 'package:pokoin/rebuild/service/card_ownership_service.dart';
import 'card_ownership_test.dart' as fixtures;

class _PendingImage extends ImageProvider<String> {
  const _PendingImage(this.url, this.pending);
  final String url;
  final Future<ImageInfo> Function(String) pending;
  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(url);
  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(pending(key));
}

void main() {
  const scans = 'de,es,fr,it,pt:sv/sv03/173';
  const service = CardOwnershipService();
  const fallback = 'catalogue';
  const scanKey = ValueKey('visible-scan');
  test(
      'parses only explicitly advertised language paths; model/cache round trip',
      () {
    final card = MarketplaceCard.fromJson({
      'id': '512138',
      'name': 'Audino',
      'langScans': scans,
    });
    expect(card.languageImageUrls['IT'],
        'https://assets.tcgdex.net/it/sv/sv03/173/high.webp');
    expect(card.languageImageUrls, hasLength(5));
    expect(card.languageImageUrls.containsKey('EN'), isFalse);
    expect(MarketplaceCard.fromJson(card.toJson()).languageImageUrls,
        card.languageImageUrls);
    expect(CardLanguageArtwork.parse('it:../../173'), isEmpty);
    expect(CardLanguageArtwork.parse('it:https://evil.example/a/b'), isEmpty);
    expect(CardLanguageArtwork.parse('xx:sv/sv03/173'), isEmpty);
    expect(CardLanguageArtwork.parse('it:sv/sv03/173;it:sv/sv03/174'), isEmpty);
    expect(
        () => card.languageImageUrls['IT'] = 'changed', throwsUnsupportedError);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'detail controls move outside scan corners at text scale $scale',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                  body: Center(
                      child: SizedBox(
                          width: 290,
                          child: CardDetailsArtwork(
                              cardId: '24',
                              cardName: 'Audino',
                              fallbackUrl: fallback,
                              languageImages: const {},
                              ownership:
                                  service.describe(fixtures.owned(), '24'),
                              imageBuilder: (_) =>
                                  const SizedBox.expand(key: scanKey))))))));
      await tester.pumpAndSettle();
      final scan = tester.getRect(find.byKey(scanKey));
      final flag = tester.getRect(find.byType(CardLanguageFlag));
      final quantity = tester.getRect(find.byType(CollectionQuantityBadge));
      expect(scan.width, closeTo(266, .001));
      expect(scan.width / scan.height, closeTo(.716, .001));
      expect(flag.top, lessThan(scan.top));
      expect(flag.right, greaterThan(scan.right));
      // Emoji width depends on the platform font; its outside edge is fixed.
      expect(flag.right - scan.right, closeTo(9, .001));
      expect(quantity.right, greaterThan(scan.right));
      expect(quantity.bottom, greaterThan(scan.bottom));
      expect(quantity.top, greaterThan(scan.bottom - 24));
      expect(
          tester.getSize(find.byType(CardLanguageBadge)), const Size(48, 48));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'background warming is bounded, owned-only, switch uses prepared image; retry is local',
      (tester) async {
    final pending = <String, List<Completer<ImageInfo>>>{};
    final starts = <String>[];
    final widths = <int>[];
    Future<ImageInfo> load(String url) {
      starts.add(url);
      final reply = Completer<ImageInfo>();
      (pending[url] ??= []).add(reply);
      return reply.future;
    }

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.green, BlendMode.src);
    final picture = recorder.endRecording();
    final bitmap = (await tester.runAsync(() => picture.toImage(2, 3)))!;
    picture.dispose();
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      bitmap.dispose();
    });
    final collection = CardCollection(status: CollectionStatus.ready, items: [
      fixtures.copy('IT', 2),
      fixtures.copy('FR', 1),
      fixtures.copy('DE', 1),
    ]);
    final selected = ValueNotifier('IT');
    addTearDown(selected.dispose);
    final images = CardLanguageArtwork.parse(scans);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
      child: SizedBox(
          width: 290,
          child: ValueListenableBuilder<String>(
            valueListenable: selected,
            builder: (_, language, __) => CardDetailsArtwork(
                cardId: '24',
                cardName: 'Audino',
                fallbackUrl: fallback,
                languageImages: images,
                ownership: service.describe(collection, '24',
                    selectedLanguage: language),
                onLanguageSelected: (value) => selected.value = value,
                imageProvider: (url, width) {
                  widths.add(width);
                  return _PendingImage(url, load);
                },
                imageBuilder: (url) => Center(child: Text(url, key: scanKey))),
          )),
    ))));
    await tester.pump();
    expect(find.text(fallback), findsOneWidget); // Never block opening.
    expect(starts, hasLength(2));
    expect(starts, contains(images['IT']));
    expect(starts, isNot(contains(images['ES']))); // Not owned.
    final decodeWidth =
        (266 * tester.view.devicePixelRatio).round().clamp(1, 768);
    expect(widths.every((width) => width == decodeWidth), isTrue);
    final other = starts.firstWhere((url) => url != images['IT']);
    pending[other]!.last.completeError(StateError('image unavailable'));
    await tester.pump();
    await tester.pump();
    expect(
        starts, hasLength(3)); // Next queued language, still max two in flight.
    pending[images['IT']]!.last.complete(ImageInfo(image: bitmap.clone()));
    final last = starts.last;
    pending[last]!.last.complete(ImageInfo(image: bitmap.clone()));
    await tester.pumpAndSettle();
    expect(find.text(images['IT']!), findsOneWidget);
    expect(find.text('×4'), findsOneWidget);
    await tester.tap(find.byType(CardLanguageBadge));
    await tester.pumpAndSettle();
    final failedCode =
        images.entries.firstWhere((entry) => entry.value == other).key;
    await tester.ensureVisible(fixtures.option(failedCode));
    await tester.tap(fixtures.option(failedCode));
    await tester.pumpAndSettle();
    expect(selected.value, failedCode);
    expect(find.text(fallback), findsOneWidget);
    expect(find.textContaining('non disponibile'), findsOneWidget);
    await tester.tap(find.text('Riprova immagine'));
    await tester.pump();
    await tester.pump();
    expect(starts, hasLength(4));
    pending[other]!.last.complete(ImageInfo(image: bitmap.clone()));
    await tester.pumpAndSettle();
    expect(find.text(other), findsOneWidget);
    selected.value = 'IT';
    await tester.pumpAndSettle();
    expect(find.text(images['IT']!), findsOneWidget);
    expect(starts, hasLength(4)); // Ready switch/rebuild does not fetch again.
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing details stops queued work and ignores late image errors',
      (tester) async {
    final starts = <String>[];
    final replies = <Completer<ImageInfo>>[];
    final collection = CardCollection(status: CollectionStatus.ready, items: [
      fixtures.copy('IT', 1),
      fixtures.copy('FR', 1),
      fixtures.copy('DE', 1),
    ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 290,
                child: CardDetailsArtwork(
                    cardId: '24',
                    cardName: 'Audino',
                    fallbackUrl: fallback,
                    languageImages: CardLanguageArtwork.parse(scans),
                    ownership: service.describe(collection, '24'),
                    imageBuilder: (_) => const SizedBox.shrink(),
                    imageProvider: (url, _) => _PendingImage(url, (key) {
                          starts.add(key);
                          final reply = Completer<ImageInfo>();
                          replies.add(reply);
                          return reply.future;
                        }))))));
    await tester.pump();
    expect(starts, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    for (final reply in replies) {
      reply.completeError(StateError('late'));
    }
    await tester.pumpAndSettle();
    expect(starts, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
