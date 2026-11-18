import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokoin/rebuild/controller/shipping_addresses_controller.dart';
import 'package:pokoin/rebuild/controller/scan_clipboard_controller.dart';
import 'package:pokoin/rebuild/model/shipping_address.dart';
import 'package:pokoin/rebuild/model/listing_draft.dart';
import 'package:pokoin/rebuild/provider/account_addresses_provider.dart';
import 'package:pokoin/rebuild/provider/draft_listing_provider.dart';
import 'package:pokoin/rebuild/service/shipping_addresses_service.dart';
import 'package:pokoin/rebuild/service/scan_clipboard_service.dart';
import 'package:pokoin/rebuild/presentation/profile/shipping_addresses_screen.dart';
import 'scan_clipboard_test.dart' show MemoryClipboard;
import 'scanner_test.dart' as scan;

const address = ShippingAddress(
    id: 'a/1',
    label: 'Casa',
    fullName: 'Mario Test',
    addressLine1: 'Via Esempio 1',
    postalCode: '00100',
    city: 'Roma',
    countryCode: 'IT',
    isDefault: true);

class FakeAddresses extends ShippingAddressesService {
  List<ShippingAddress> rows = [address];
  Completer<List<ShippingAddress>>? pending;
  Completer<String>? countryPending;
  int writes = 0;
  @override
  Future<List<ShippingAddress>> read(String uid) async =>
      pending == null ? rows : pending!.future;
  @override
  Future<String> defaultCountry(String uid) async => countryPending == null
      ? (rows.where((a) => a.isDefault).firstOrNull ?? rows.firstOrNull)
              ?.countryCode ??
          ''
      : countryPending!.future;
  @override
  Future<void> save(String uid, ShippingAddress value) async {
    writes++;
    rows = [value];
  }

  @override
  Future<void> remove(String uid, String id) async {
    writes++;
    rows = [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontRoot = Platform.environment['SCANNER_PREVIEW_FONTS'];
    if (fontRoot == null) return;
    for (final e in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final bytes = await File('$fontRoot/${e.value}').readAsBytes();
      await (FontLoader(e.key)
            ..addFont(Future.value(bytes.buffer.asByteData())))
          .load();
    }
  });
  test(
      'owner address CRUD uses authenticated contract and metadata avoids reveal',
      () async {
    final calls = <http.Request>[];
    final provider = AccountAddressesProvider(token: (uid) async {
      expect(uid, 'alice');
      return 'owner-token';
    }, client: MockClient((r) async {
      calls.add(r);
      expect(r.url.path, '/api/account-addresses');
      expect(r.headers['Authorization'], 'Bearer owner-token');
      return http.Response(
          jsonEncode(r.method == 'GET'
              ? {
                  'addresses': [
                    {'id': 'secondary', 'countryCode': 'FR'},
                    {...address.toJson(), 'id': address.id}
                  ]
                }
              : r.method == 'DELETE'
                  ? {}
                  : {
                      'address': {'id': address.id}
                    }),
          200);
    }));
    final service = ShippingAddressesService(provider: provider);
    expect(await service.defaultCountry('alice'), 'IT');
    expect(calls.last.url.queryParameters.containsKey('reveal'), false);
    expect((await service.read('alice')).last.fullName, 'Mario Test');
    expect(calls.last.url.queryParameters['reveal'], '1');
    await service.save('alice', ShippingAddress.fromJson(address.toJson()));
    expect(calls.last.method, 'POST');
    expect(jsonDecode(calls.last.body)['countryCode'], 'IT');
    await service.save('alice', address);
    expect(calls.last.method, 'PUT');
    expect(calls.last.url.queryParameters['id'], 'a/1');
    await service.remove('alice', address.id);
    expect(calls.last.method, 'DELETE');
    expect(calls.last.url.queryParameters['id'], 'a/1');
  });
  test('required address fields reject before HTTP; unacknowledged writes fail',
      () async {
    var calls = 0;
    final service = ShippingAddressesService(
        provider: AccountAddressesProvider(
            token: (_) async => 'token',
            client: MockClient((r) async {
              calls++;
              return http.Response('{}', 200);
            })));
    expect(
        () => service.save('alice', const ShippingAddress(countryCode: 'IT')),
        throwsFormatException);
    expect(calls, 0);
    await expectLater(service.save('alice', address), throwsFormatException);
  });
  test('account switch clears address data and ignores late owner response',
      () async {
    final service = FakeAddresses();
    final c = ShippingAddressesController(service: service)..setUser('alice');
    await c.load();
    expect(c.items.single.fullName, 'Mario Test');
    service.pending = Completer<List<ShippingAddress>>();
    final load = c.load();
    c.setUser('bob');
    expect(c.items, isEmpty);
    service.pending!.complete([address]);
    await load;
    expect(c.items, isEmpty);
    expect(c.loaded, false);
    c.dispose();
  });
  test(
      'country defaults from active address, manual overrides and account changes win',
      () async {
    final addresses = FakeAddresses();
    final c = ScanClipboardController(
        service: ScanClipboardService(
            local: MemoryClipboard(), addresses: addresses));
    await c.setUser('alice');
    await c.storeScans([scan.row]);
    await c.loadSellerCountry(scan.row.id);
    expect(c.items.single.shipFromCountry, 'IT');
    addresses.countryPending = Completer<String>();
    final pending = c.loadSellerCountry(scan.row.id);
    await c.edit(scan.row.id,
        (d) => d.edit(shipFromCountry: 'FR', shipFromCountryManual: true));
    addresses.countryPending!.complete('DE');
    await pending;
    expect(c.items.single.shipFromCountry, 'FR');
    await c.edit(scan.row.id, (d) => d.edit(shipFromCountryManual: false));
    addresses.countryPending = Completer<String>();
    final late = c.loadSellerCountry(scan.row.id);
    await c.setUser('bob');
    await c.storeScans([scan.row]);
    addresses.countryPending!.complete('DE');
    await late;
    expect(c.items.single.shipFromCountry, '');
    c.dispose();
  });
  test('empty address book falls back to seller settings and country persists',
      () async {
    final local = MemoryClipboard();
    final service = ScanClipboardService(
        local: local,
        addresses: FakeAddresses()..rows = [],
        listings: DraftListingProvider(
            token: (_) async => 'token',
            client: MockClient((r) async {
              expect(r.method, 'GET');
              expect(r.url.path, '/api/marketplace-seller-settings');
              return http.Response('{"shipFromCountry":"FR"}', 200);
            })));
    expect(await service.sellerCountry('alice'), 'FR');
    const draft = ListingDraft(
        card: scan.row, shipFromCountry: 'FR', shipFromCountryManual: true);
    await local.write('alice', [draft]);
    final restored = (await local.read('alice')).single;
    expect(restored.shipFromCountry, 'FR');
    expect(restored.shipFromCountryManual, true);
    final oldSnapshot = const ListingDraft(card: scan.row).toJson()
      ..remove('shipFromCountry')
      ..remove('shipFromCountryManual');
    expect(ListingDraft.fromJson(oldSnapshot).shipFromCountry, '');
  });
  test(
      'shipping without country and grading without certification block all writes',
      () async {
    var writes = 0;
    final service = ScanClipboardService(
        local: MemoryClipboard(),
        listings: DraftListingProvider(
            token: (_) async => 'token',
            client: MockClient((r) async {
              writes++;
              return http.Response('{}', 200);
            })));
    final draft = ListingDraft(card: scan.row.edit(price: '10'));
    expect(
        () => service.publish('alice', draft, 'Seller'), throwsFormatException);
    expect(
        () => service.publish(
            'alice',
            draft.edit(
                shipFromCountry: 'IT',
                graded: true,
                gradingCompany: 'PSA',
                grade: '10'),
            'Seller'),
        throwsFormatException);
    expect(writes, 0);
  });
  test('country setting failure never creates listing and remains editable',
      () async {
    final calls = <String>[];
    final c = ScanClipboardController(
        service: ScanClipboardService(
            local: MemoryClipboard(),
            listings: DraftListingProvider(
                token: (_) async => 'token',
                client: MockClient((r) async {
                  calls.add(r.url.path);
                  return http.Response(
                      '{"error":"shipFromCountry required"}', 400);
                }))));
    await c.setUser('alice');
    await c.storeScans([scan.row.edit(price: '10')]);
    await c.edit(scan.row.id, (d) => d.edit(shipFromCountry: 'IT'));
    expect(await c.publish(scan.row.id), false);
    expect(calls, ['/api/marketplace-seller-settings']);
    expect(c.items.single.editable, true);
    expect(c.error, contains('shipFromCountry required'));
    c.dispose();
  });
  test(
      'listing HTTP 400 exposes validation reason with tokens redacted; 500 stays generic',
      () async {
    for (final status in [400, 500]) {
      final calls = <String>[];
      final provider = DraftListingProvider(
          token: (_) async => 'token',
          client: MockClient((r) async {
            calls.add(r.url.path);
            if (r.url.path.endsWith('seller-settings')) {
              return http.Response('{"shipFromCountry":"IT"}', 200);
            }
            return http.Response(
                '{"error":"Country invalid Bearer secret-token"}', status);
          }));
      try {
        await provider.publish(
            'alice',
            ListingDraft(
                card: scan.row.edit(price: '10'), shipFromCountry: 'IT'),
            'Seller');
        fail('Expected failure');
      } on DraftPublishFailure catch (e) {
        expect(e.definite, status == 400);
        expect(e.message, isNot(contains('secret-token')));
        expect(e.message.contains('Country invalid'), status == 400);
      }
      expect(calls,
          ['/api/marketplace-seller-settings', '/api/marketplace-listings']);
    }
  });
  testWidgets(
      'phone address editor persists fields, sets default and hides data after logout',
      (tester) async {
    final fontRoot = Platform.environment['SCANNER_PREVIEW_FONTS'];
    final service = FakeAddresses();
    final c = ShippingAddressesController(service: service)..setUser('alice');
    final shot = GlobalKey();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.dark),
        builder: (context, child) => RepaintBoundary(key: shot, child: child!),
        home: ShippingAddressesScreen(controller: c)));
    await tester.pumpAndSettle();
    expect(find.text('Predefinito'), findsOneWidget);
    expect(find.textContaining('Via Esempio 1'), findsOneWidget);
    if (fontRoot != null) {
      await tester.runAsync(() async {
        final pixels = await (shot.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
        await File('build/shipping-addresses.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        pixels.dispose();
      });
    }
    await tester.tap(find.text('Modifica'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'), 'Milano');
    await tester.ensureVisible(find.text('Salva indirizzo'));
    await tester.tap(find.text('Salva indirizzo'));
    await tester.pumpAndSettle();
    expect(service.rows.single.city, 'Milano');
    expect(service.rows.single.isDefault, true);
    await tester.tap(find.text('Modifica'));
    await tester.pumpAndSettle();
    c.setUser(null);
    await tester.pumpAndSettle();
    expect(find.text('Mario Test'), findsNothing);
    expect(find.textContaining('Account cambiato'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
