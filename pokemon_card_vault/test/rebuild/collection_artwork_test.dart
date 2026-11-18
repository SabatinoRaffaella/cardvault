import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pokoin/rebuild/controller/collection_artwork_controller.dart';
import 'package:pokoin/rebuild/controller/cardex_controller.dart';
import 'package:pokoin/rebuild/model/card.dart';
import 'package:pokoin/rebuild/presentation/shared/component/collection_card_artwork.dart';
import 'package:pokoin/rebuild/presentation/shared/component/collection_language_button.dart';
import 'package:pokoin/rebuild/provider/artwork_preferences_provider.dart';
import 'package:pokoin/rebuild/service/collection_artwork_service.dart';
import 'card_ownership_test.dart' as fixtures;

const italian = 'https://assets.tcgdex.net/it/sv/sv03/173/high.webp';
MarketplaceCard metadata(String id, {String scans = 'it,fr:sv/sv03/173'}) =>
    MarketplaceCard(
        id: id,
        name: 'Audino',
        expansion: 'Obsidian Flames',
        number: '173/197',
        imageUrl: 'english.jpg',
        languageScans: scans);

class PendingService extends CollectionArtworkService {
  final requests = <String>[];
  final pending = <String, Completer<MarketplaceCard>>{};
  Completer<String>? saved;
  @override
  Future<String> readLanguage() => saved?.future ?? Future.value('IT');
  @override
  Future<void> writeLanguage(String code) async {}
  @override
  Future<MarketplaceCard> fetchCard(String id) {
    requests.add(id);
    return (pending[id] = Completer<MarketplaceCard>()).future;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Italian default, validated saved preference and ordered writes',
      () async {
    final controller = CollectionArtworkController();
    await controller.start();
    expect(controller.language, 'IT');
    controller.selectLanguage('EN');
    controller.selectLanguage('FR');
    controller.selectLanguage('unsupported');
    await tick();
    final restored = CollectionArtworkController();
    await restored.start();
    expect(restored.language, 'FR');
    expect(await ArtworkPreferencesProvider().readLanguage(), 'FR');
    controller.dispose();
    restored.dispose();
  });

  test('a late stored language cannot overwrite an explicit new choice',
      () async {
    final service = PendingService()..saved = Completer<String>();
    final controller = CollectionArtworkController(service: service);
    final starting = controller.start();
    controller.selectLanguage('EN');
    service.saved!.complete('FR');
    await starting;
    expect(controller.language, 'EN');
    controller.dispose();
  });

  test(
      'two metadata requests, shared leases, cancelled queued sleeves and cached failures',
      () async {
    final service = PendingService();
    final controller = CollectionArtworkController(service: service);
    await controller.start();
    final first = controller.acquire('24');
    final duplicate = controller.acquire('24');
    controller.acquire('25');
    final cancelled = controller.acquire('26');
    controller.acquire('27');
    cancelled();
    first();
    expect(service.requests, ['24', '25']);
    service.pending['24']!.complete(metadata('24'));
    await tick();
    expect(service.requests, ['24', '25', '27']);
    expect(controller.metadataFor('24')!.languageImageUrls['IT'], italian);
    service.pending['25']!.completeError(StateError('offline'));
    service.pending['27']!.complete(metadata('27', scans: ''));
    await tick();
    expect(controller.resolved('25'), isTrue);
    controller.acquire('25');
    duplicate();
    expect(service.requests.where((id) => id == '25'), hasLength(1));
    controller.acquire('invalid');
    expect(service.requests, ['24', '25', '27']);
    controller.dispose();
  });

  test('disposal ignores late metadata and never starts the remaining queue',
      () async {
    final service = PendingService();
    final controller = CollectionArtworkController(service: service);
    await controller.start();
    controller.acquire('24');
    controller.acquire('25');
    controller.acquire('26');
    controller.dispose();
    service.pending['24']!.complete(metadata('24'));
    service.pending['25']!.completeError(StateError('offline'));
    await tick();
    expect(service.requests, ['24', '25']);
  });

  test(
      'global image preference never filters copies; detail selection remains independent',
      () async {
    final service = PendingService();
    final artwork = CollectionArtworkController(service: service);
    final controller = CardexController(artwork: artwork)
      ..collection = fixtures.owned();
    await artwork.start();
    controller.setArtworkLanguage('FR');
    expect(controller.visibleCards, hasLength(1));
    expect(controller.collection.copies, 3);
    expect(controller.detailsOwnershipFor('24').selectedLanguage, 'IT');
    expect(
        controller
            .detailsOwnershipFor('24', selectedLanguage: 'EN')
            .selectedLanguage,
        'EN');
    expect(artwork.language, 'FR');
    expect(controller.artworkLanguageFor('24'), 'FR');
    final release = artwork.acquire('24');
    service.pending['24']!.complete(metadata('24'));
    await tick();
    controller.setArtworkLanguage('IT');
    final preview = controller.artworkPreview(fixtures.audino);
    expect(preview.id, '24');
    expect(preview.imageLanguage, 'IT');
    expect(preview.fullImageUrl, italian);
    release();
    controller.dispose();
  });

  testWidgets(
      'localized sleeve does not flash English while resolving; changing language reuses metadata',
      (tester) async {
    final service = PendingService();
    final controller = CollectionArtworkController(service: service);
    await controller.start();
    final rendered = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 180,
                height: 120,
                child: ListenableBuilder(
                    listenable: controller,
                    builder: (_, __) => CollectionCardArtwork(
                        controller: controller,
                        cardId: '24',
                        language: controller.language,
                        fallbackUrl: 'english.jpg',
                        imageBuilder: (url, _) {
                          rendered.add(url);
                          return Text(url);
                        }))))));
    await tester.pump();
    expect(rendered, isEmpty);
    service.pending['24']!.complete(metadata('24'));
    await tester.pumpAndSettle();
    expect(find.text(italian), findsOneWidget);
    expect(rendered, isNot(contains('english.jpg')));
    controller.selectLanguage('EN');
    await tester.pumpAndSettle();
    expect(find.text('english.jpg'), findsOneWidget);
    controller.selectLanguage('IT');
    await tester.pumpAndSettle();
    expect(find.text(italian), findsOneWidget);
    expect(service.requests, ['24']);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
      'missing manifest or failed localized image has explicit catalogue fallback',
      (tester) async {
    final service = PendingService();
    final controller = CollectionArtworkController(service: service);
    await controller.start();
    VoidCallback? fail;
    Widget sleeve(String id) => MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 180,
                height: 120,
                child: CollectionCardArtwork(
                    key: ValueKey(id),
                    controller: controller,
                    cardId: id,
                    language: 'IT',
                    fallbackUrl: 'english.jpg',
                    imageBuilder: (url, onError) {
                      fail = onError;
                      return Text(url);
                    }))));
    await tester.pumpWidget(sleeve('24'));
    service.pending['24']!.complete(metadata('24'));
    await tester.pumpAndSettle();
    fail!();
    await tester.pumpAndSettle();
    expect(find.text('english.jpg'), findsOneWidget);
    expect(find.text('Catalogo'), findsOneWidget);
    await tester.pumpWidget(sleeve('25'));
    service.pending['25']!.complete(metadata('25', scans: ''));
    await tester.pumpAndSettle();
    expect(find.text('Catalogo'), findsOneWidget);
    expect(find.text('english.jpg'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
      'toolbar menu retains a compact target to the left of the cart at 320px',
      (tester) async {
    final controller = CollectionArtworkController(service: PendingService());
    await controller.start();
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: AppBar(title: const Text('pokoin'), actions: [
      CollectionLanguageButton(
          controller: controller, onSelected: controller.selectLanguage),
      IconButton(
          tooltip: 'Carrello',
          onPressed: () {},
          icon: const Icon(Icons.shopping_bag_outlined)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.content_paste)),
    ]))));
    expect(tester.getCenter(find.byType(CollectionLanguageButton)).dx,
        lessThan(tester.getCenter(find.byTooltip('Carrello')).dx));
    await tester.tap(find.byTooltip('Lingua immagini: Italiano'));
    await tester.pumpAndSettle();
    final english = find.byWidgetPredicate((widget) =>
        widget is CheckedPopupMenuItem<String> && widget.value == 'EN');
    await tester.ensureVisible(english);
    await tester.pumpAndSettle();
    await tester.tap(english);
    await tester.pumpAndSettle();
    expect(controller.language, 'EN');
    expect(find.byTooltip('Lingua immagini: Inglese'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
