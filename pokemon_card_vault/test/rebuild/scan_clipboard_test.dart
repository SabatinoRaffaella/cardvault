import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokoin/rebuild/controller/scan_clipboard_controller.dart';
import 'package:pokoin/rebuild/controller/scanner_controller.dart';
import 'package:pokoin/rebuild/controller/cart_controller.dart';
import 'package:pokoin/rebuild/controller/card_details_controller.dart';
import 'package:pokoin/rebuild/service/card_service.dart';
import 'package:pokoin/rebuild/presentation/card_details/card_details.dart';
import 'package:pokoin/rebuild/model/listing_draft.dart';
import 'package:pokoin/rebuild/model/scanner.dart';
import 'package:pokoin/rebuild/provider/scan_clipboard_provider.dart';
import 'package:pokoin/rebuild/provider/draft_listing_provider.dart';
import 'package:pokoin/rebuild/service/scan_clipboard_service.dart';
import 'package:pokoin/rebuild/presentation/scanner/scanner_screen.dart';
import 'package:pokoin/rebuild/presentation/shared/component/scan_clipboard_button.dart';
import 'package:pokoin/rebuild/presentation/shared/component/scan_clipboard_sheet.dart';
import 'package:pokoin/rebuild/presentation/card_details/component/draft_listing_composer.dart';
import 'scanner_test.dart' as scan;

class MemoryClipboard extends ScanClipboardProvider {
  final saved = <String?, String>{};
  bool failRead = false, failWrite = false;
  Completer<void>? blockedWrite;
  @override
  Future<List<ListingDraft>> read(String? uid) async {
    if (failRead) throw StateError('Read failed');
    final json = saved[uid];
    return json == null
        ? []
        : (jsonDecode(json) as List)
            .map((d) =>
                ListingDraft.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList();
  }

  @override
  Future<void> write(String? uid, List<ListingDraft> drafts) async {
    if (blockedWrite != null) await blockedWrite!.future;
    if (failWrite) throw StateError('Write failed');
    saved[uid] = jsonEncode(drafts.map((d) => d.toJson()).toList());
  }
}

ScanClipboardController clipboard(MemoryClipboard local,
        {DraftListingProvider? listings}) =>
    ScanClipboardController(
        service: ScanClipboardService(local: local, listings: listings));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fontRoot = Platform.environment['SCANNER_PREVIEW_FONTS'];
  setUpAll(() async {
    if (fontRoot == null) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final bytes = await File('$fontRoot/${entry.value}').readAsBytes();
      await (FontLoader(entry.key)
            ..addFont(Future.value(bytes.buffer.asByteData())))
          .load();
    }
  });
  ThemeData previewTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF11121A),
      colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE9FF72),
          brightness: Brightness.dark,
          primary: const Color(0xFFE9FF72),
          surface: const Color(0xFF1D1F2C)));
  Future<void> snapshot(WidgetTester tester, GlobalKey key, String name) async {
    if (fontRoot == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixels = await boundary.toImage(pixelRatio: 2);
      final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
      await File('build/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      pixels.dispose();
    });
  }

  test(
      'Hive snapshots survive close/reopen with selections and separate account scopes',
      () async {
    final temp = await Directory.systemTemp.createTemp('pokoin-clipboard-');
    Hive.init(temp.path);
    final provider = HiveScanClipboardProvider(initialize: () async {});
    try {
      final draft = ListingDraft(
              card: scan.row.edit(
                  price: '12,50',
                  condition: 'SP',
                  language: 'JP',
                  quantity: 4,
                  foilState: 'reverse',
                  alternatives: [scan.candidate, scan.other]))
          .edit(comment: 'Angolo segnato', firstEdition: true);
      await provider.write('alice', [draft]);
      await provider
          .write(null, [ListingDraft(card: scan.row.edit(price: 'NaN'))]);
      await Hive.close();
      final restored = (await provider.read('alice')).single;
      expect(restored.card.price, '12,50');
      expect(restored.card.language, 'JP');
      expect(restored.card.condition, 'SP');
      expect(restored.card.quantity, 4);
      expect(restored.card.foilState, 'reverse');
      expect(restored.card.alternatives.length, 2);
      expect(restored.comment, 'Angolo segnato');
      expect(restored.firstEdition, true);
      expect(await provider.read('bob'), isEmpty);
      expect((await provider.read(null)).single.card.price, 'NaN');
    } finally {
      await Hive.close();
      await temp.delete(recursive: true);
    }
  });
  test(
      'copy commits before clearing scans; failed disk write can retry without duplicates',
      () async {
    final local = MemoryClipboard()..failWrite = true;
    final clip = clipboard(local);
    await clip.setUser('alice');
    final source = scan.Source();
    final scanner =
        ScannerController(service: source, storeDrafts: clip.storeScans)
          ..setUser('alice');
    await scanner.start();
    scan.capture(scanner);
    scanner.edit(scanner.cards.single
        .edit(condition: 'SP', language: 'FR', price: '20'));
    expect(await scanner.copyToClipboard(), false);
    expect(scanner.cards.length, 1);
    expect(clip.pendingCount, 0);
    local.failWrite = false;
    expect(await scanner.copyToClipboard(), true);
    expect(scanner.cards, isEmpty);
    expect(clip.pendingCount, 1);
    expect(clip.transferRevision, 1);
    expect(clip.items.single.card.price, '20');
    expect(clip.items.single.card.language, 'FR');
    expect(source.additions, 0);
    expect(source.saves, 0);
    final restored = clipboard(local);
    await restored.setUser('alice');
    expect(restored.pendingCount, 1);
    scanner.dispose();
    clip.dispose();
    restored.dispose();
  });
  test('failed clipboard read prevents overwriting the existing snapshot',
      () async {
    final local = MemoryClipboard()
      ..saved['alice'] = 'private-existing-data'
      ..failRead = true;
    final clip = clipboard(local);
    await clip.setUser('alice');
    await expectLater(clip.storeScans([scan.row]), throwsStateError);
    expect(local.saved['alice'], 'private-existing-data');
    expect(clip.available, false);
    clip.dispose();
  });
  test(
      'serialized field edits preserve both changes and late account writes stay scoped',
      () async {
    final local = MemoryClipboard();
    final clip = clipboard(local);
    await clip.setUser('alice');
    await clip.storeScans([scan.row]);
    await Future.wait([
      clip.edit(scan.row.id, (d) => d.edit(card: d.card.edit(price: '30'))),
      clip.edit(scan.row.id, (d) => d.edit(card: d.card.edit(language: 'JP'))),
    ]);
    expect(clip.items.single.card.price, '30');
    expect(clip.items.single.card.language, 'JP');
    local.blockedWrite = Completer<void>();
    final pending =
        clip.edit(scan.row.id, (d) => d.edit(comment: 'Private note'));
    await Future<void>.delayed(Duration.zero);
    await clip.setUser('bob');
    local.blockedWrite!.complete();
    expect(await pending, false);
    expect(clip.items, isEmpty);
    await clip.setUser('alice');
    expect(clip.items.single.comment, 'Private note');
    clip.dispose();
  });
  test(
      'manual publication sends one selected card and double tap creates one POST',
      () async {
    final local = MemoryClipboard();
    final completion = Completer<http.Response>();
    final calls = <http.Request>[];
    final provider = DraftListingProvider(
        token: (_) async => 'token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('seller-settings')) {
            return http.Response('{"shipFromCountry":"IT"}', 200);
          }
          calls.add(request);
          expect(
              (await local.read('alice')).single.status, DraftStatus.uncertain);
          return completion.future;
        }));
    final clip = clipboard(local, listings: provider);
    await clip.setUser('alice');
    await clip.storeScans([
      scan.row.edit(
          price: '12,50',
          language: 'JP',
          condition: 'SP',
          quantity: 3,
          foilState: 'reverse')
    ]);
    await clip.edit(scan.row.id, (d) => d.edit(shipFromCountry: 'IT'));
    final first = clip.publish(scan.row.id);
    final second = clip.publish(scan.row.id);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls.length, 1);
    final body = jsonDecode(calls.single.body) as Map;
    expect(calls.single.url.path, '/api/marketplace-listings');
    expect(body['cardId'], '124');
    expect(body['pricePkn'], 12.5);
    expect(body['shipFromCountry'], 'IT');
    expect(body['sellerCountry'], 'IT');
    expect(body['gradingCompany'], isNull);
    expect(calls.single.url.queryParameters['game'], 'pokemon');
    expect(body['quantityAvailable'], 3);
    expect(body['language'], 'JP');
    expect(body['foilState'], 'reverse');
    expect(body['targets'], {'pokoin': true, 'cardtrader': false});
    expect(body['sourceListingId'], 'clipboard:row-1');
    completion.complete(http.Response(
        '{"id":"published-1","cardId":"124","sellerUid":"alice","sourceListingId":"clipboard:row-1"}',
        200));
    expect(await first, true);
    expect(await second, false);
    expect(clip.pendingCount, 0);
    expect(await clip.publish(scan.row.id), false);
    expect(calls.length, 1);
    clip.dispose();
  });
  test(
      'uncertain publication survives restart and reconciles with a GET, never a second POST',
      () async {
    final local = MemoryClipboard();
    final calls = <http.Request>[];
    final provider = DraftListingProvider(
        token: (_) async => 'token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('seller-settings')) {
            return http.Response('{"shipFromCountry":"IT"}', 200);
          }
          calls.add(request);
          if (request.method == 'POST') {
            throw TimeoutException('Response lost after commit');
          }
          return http.Response(
              jsonEncode({
                'listings': [
                  {
                    'id': 'published-1',
                    'sellerUid': 'alice',
                    'cardId': '124',
                    'sourceListingId': 'clipboard:row-1'
                  }
                ]
              }),
              200);
        }));
    var clip = clipboard(local, listings: provider);
    await clip.setUser('alice');
    await clip.storeScans([scan.row.edit(price: '4')]);
    await clip.edit(scan.row.id, (d) => d.edit(shipFromCountry: 'IT'));
    expect(await clip.publish(scan.row.id), false);
    expect(clip.items.single.status, DraftStatus.uncertain);
    clip.dispose();
    clip = clipboard(local, listings: provider);
    await clip.setUser('alice');
    expect(await clip.publish(scan.row.id), false);
    await clip.reconcile(scan.row.id);
    expect(clip.items.single.status, DraftStatus.published);
    expect(calls.map((c) => c.method), ['POST', 'GET']);
    clip.dispose();
  });
  test('invalid price and incomplete grading prevent the remote publication',
      () async {
    var posts = 0;
    final local = MemoryClipboard();
    final clip = clipboard(local,
        listings: DraftListingProvider(
            token: (_) async => 'token',
            client: MockClient((_) async {
              posts++;
              return http.Response('{}', 200);
            })));
    await clip.setUser('alice');
    await clip.storeScans([scan.row]);
    expect(await clip.publish(scan.row.id), false);
    await clip.edit(
        scan.row.id,
        (d) => d.edit(
            card: d.card.edit(price: '10'),
            graded: true,
            shipFromCountry: 'IT'));
    expect(await clip.publish(scan.row.id), false);
    expect(posts, 0);
    expect(clip.items.single.editable, true);
    clip.dispose();
  });
  testWidgets(
      'Batch transfers to the top counter, disables Save, and keeps clipboard tappable',
      (tester) async {
    final shot = GlobalKey();
    final local = MemoryClipboard();
    final clip = clipboard(local);
    await clip.setUser('alice');
    final source = scan.Source();
    final scanner =
        ScannerController(service: source, storeDrafts: clip.storeScans)
          ..setUser('alice');
    ListingDraft? selected;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        theme: previewTheme(),
        builder: (context, child) => RepaintBoundary(key: shot, child: child!),
        home: Scaffold(
            appBar: AppBar(title: const Text('pokoin'), actions: [
              Builder(
                  builder: (context) => ScanClipboardButton(
                      controller: clip,
                      onPressed: () async {
                        selected = await showScanClipboardSheet(
                            context: context, controller: clip);
                      })),
            ]),
            body: ScannerScreen(
                controller: scanner,
                onLogin: () {},
                onSaved: () {},
                cameraBuilder: (_) => const ColoredBox(color: Colors.black)))));
    await tester.tap(find.text('Ready · Avvia scanner'));
    await tester.pumpAndSettle();
    scan.capture(scanner);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Apri o chiudi carte scansionate'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Save'))
            .onPressed,
        isNull);
    await snapshot(tester, shot, 'clipboard-batch');
    await tester.tap(find.text('Copy to Clipboard'));
    await tester.pumpAndSettle();
    expect(scanner.cards, isEmpty);
    expect(find.byTooltip('Clipboard · 1 da controllare o listare'),
        findsOneWidget);
    expect(source.saves, 0);
    await tester.tap(find.byTooltip('Clipboard · 1 da controllare o listare'));
    await tester.pumpAndSettle();
    await snapshot(tester, shot, 'clipboard-list');
    await tester.tap(find.text('Pikachu'));
    await tester.pumpAndSettle();
    expect(selected?.card.cardId, '124');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    scanner.dispose();
    clip.dispose();
  });
  testWidgets(
      'Single pauses after one capture, stores before opening, and requires Ready again',
      (tester) async {
    final local = MemoryClipboard();
    final clip = clipboard(local);
    await clip.setUser('alice');
    final scanner =
        ScannerController(service: scan.Source(), storeDrafts: clip.storeScans)
          ..setUser('alice');
    final opened = <ScannedCard>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ScannerScreen(
                controller: scanner,
                onLogin: () {},
                onSaved: () {},
                onOpenCard: (card) async {
                  expect(clip.pendingCount, 1);
                  opened.add(card);
                },
                cameraBuilder: (_) => const SizedBox()))));
    await tester.tap(find.text('Single'));
    await tester.tap(find.text('Ready · Avvia scanner'));
    await tester.pumpAndSettle();
    scan.capture(scanner);
    scan.capture(scanner, [scan.other]);
    await tester.pumpAndSettle();
    expect(opened.length, 1);
    expect(opened.single.cardId, '124');
    expect(opened.single.price, '7.50');
    expect(scanner.activated, false);
    expect(scanner.cards, isEmpty);
    expect(find.text('Ready · Avvia scanner'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    scanner.dispose();
    clip.dispose();
  });
  testWidgets(
      'listing form restores scanner selections and saves edits without publishing',
      (tester) async {
    final shot = GlobalKey();
    final local = MemoryClipboard();
    final clip = clipboard(local);
    await clip.setUser('alice');
    await clip.storeScans([
      scan.row.edit(
          price: '32',
          condition: 'SP',
          language: 'JP',
          quantity: 4,
          foilState: 'reverse')
    ]);
    await tester.pumpWidget(MaterialApp(
        theme: previewTheme(),
        builder: (context, child) => RepaintBoundary(key: shot, child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: DraftListingComposer(
                    controller: clip, draftId: scan.row.id, onLogin: () {})))));
    expect(find.text('32'), findsOneWidget);
    expect(find.text('Giapponese'), findsOneWidget);
    expect(find.text('Slightly Played'), findsOneWidget);
    expect(find.text('Reverse'), findsOneWidget);
    await snapshot(tester, shot, 'clipboard-listing-form');
    final price = find.widgetWithText(TextFormField, 'Prezzo PK');
    await tester.enterText(price, '45,20');
    await tester.pumpAndSettle();
    final restored = clipboard(local);
    await restored.setUser('alice');
    expect(restored.items.single.card.price, '45,20');
    expect(restored.items.single.status, DraftStatus.editing);
    await tester.pumpWidget(const SizedBox());
    clip.dispose();
    restored.dispose();
  });
  test('copy remains local when indicative pricing is stalled', () async {
    final source = scan.Source()..pendingPrice = Completer<ScannerMarketData>();
    final local = MemoryClipboard();
    final clip = clipboard(local);
    await clip.setUser('alice');
    final scanner =
        ScannerController(service: source, storeDrafts: clip.storeScans)
          ..setUser('alice');
    await scanner.start();
    scan.capture(scanner);
    expect(await scanner.copyToClipboard().timeout(const Duration(seconds: 4)),
        true);
    expect(clip.pendingCount, 1);
    expect(clip.items.single.card.price, isEmpty);
    source.pendingPrice!.complete(const ScannerMarketData(suggested: 100));
    await Future<void>.delayed(Duration.zero);
    expect(clip.items.single.card.price, isEmpty);
    scanner.dispose();
    clip.dispose();
  });
  testWidgets('scanner draft opens the real mobile detail at price and listing',
      (tester) async {
    final local = MemoryClipboard();
    final clip = clipboard(local);
    await clip.setUser('alice');
    await clip.storeScans(
        [scan.row.edit(price: '32', language: 'JP', condition: 'SP')]);
    final cardService = CardService(
        client: MockClient((request) async => http.Response(
            jsonEncode(request.url.path.endsWith('card-page')
                ? {
                    'card': {
                      'id': '124',
                      'name': 'Pikachu',
                      'set': 'Scarlatto e Violetto',
                      'pricePkn': 32
                    }
                  }
                : {'listings': []}),
            200)));
    final cart = CartController();
    final detail = CardDetailsController(cardId: '124', service: cardService);
    final shot = GlobalKey();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        theme: previewTheme(),
        builder: (context, child) => RepaintBoundary(key: shot, child: child!),
        home: CardDetails(
            preview: clip.items.single.preview,
            controller: detail,
            cart: cart,
            clipboard: clip,
            draftId: scan.row.id,
            onOpenClipboard: () {},
            onDraftLogin: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Prezzo e listing').hitTestable(), findsOneWidget);
    expect(find.text('32').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Clipboard · 1 da controllare o listare'),
        findsOneWidget);
    await snapshot(tester, shot, 'clipboard-detail-mobile');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    clip.dispose();
    cart.dispose();
    cardService.dispose();
  });
  test(
      'empty or foreign acknowledgements stay uncertain; wrapped owned response succeeds',
      () async {
    for (final body in [
      <String, dynamic>{},
      {
        'id': 'x',
        'cardId': '124',
        'sellerUid': 'bob',
        'sourceListingId': 'clipboard:row-1'
      },
      {
        'listing': {
          'id': 'x',
          'cardId': '124',
          'sellerUid': 'alice',
          'sourceListingId': 'clipboard:row-1'
        }
      }
    ]) {
      final local = MemoryClipboard();
      final clip = clipboard(local,
          listings: DraftListingProvider(
              token: (_) async => 'token',
              client: MockClient((request) async => http.Response(
                  jsonEncode(request.url.path.endsWith('seller-settings')
                      ? {'shipFromCountry': 'IT'}
                      : body),
                  200))));
      await clip.setUser('alice');
      await clip.storeScans([scan.row.edit(price: '4')]);
      await clip.edit(scan.row.id, (d) => d.edit(shipFromCountry: 'IT'));
      expect(await clip.publish(scan.row.id), body.containsKey('listing'));
      expect(
          clip.items.single.status,
          body.containsKey('listing')
              ? DraftStatus.published
              : DraftStatus.uncertain);
      clip.dispose();
    }
  });
}
