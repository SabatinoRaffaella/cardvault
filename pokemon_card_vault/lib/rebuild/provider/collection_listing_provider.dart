import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../model/cardex.dart';
import '../model/collection_listing.dart';

/// Owner-only switch calls. A timed-out write is never automatically repeated.
class CollectionListingProvider {
  CollectionListingProvider(
      {http.Client? client, Future<String?> Function(String)? token})
      : _client = client,
        _token = token;
  final http.Client? _client;
  final Future<String?> Function(String)? _token;

  Future<Map<String, dynamic>> _request(String uid, String method, String path,
      {Map<String, String> query = const {},
      Map<String, dynamic>? body}) async {
    final user = _token == null ? FirebaseAuth.instance.currentUser : null;
    if (_token == null && user?.uid != uid) {
      throw const CollectionSwitchFailure(
          'Accedi con lo stesso account della collezione.');
    }
    final token = await (_token != null ? _token(uid) : user!.getIdToken())
        .timeout(const Duration(seconds: 12));
    if (token == null ||
        token.isEmpty ||
        (_token == null && FirebaseAuth.instance.currentUser?.uid != uid)) {
      throw const CollectionSwitchFailure(
          'La sessione è cambiata. Accedi di nuovo.');
    }
    final client = _client ?? http.Client();
    final writing = method != 'GET';
    try {
      final request = http.Request(method,
          Uri.https('api.pokoin.com', path, {'game': 'pokemon', ...query}))
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw CollectionSwitchFailure(
            'Cambio non confermato (HTTP ${response.statusCode}).',
            uncertain: writing && response.statusCode >= 500);
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Invalid switch response');
      }
      return payload;
    } on CollectionSwitchFailure {
      rethrow;
    } catch (_) {
      throw CollectionSwitchFailure(
          writing
              ? 'Risposta non ricevuta. Verifica l’esito prima di riprovare.'
              : 'Impossibile verificare la collezione. Riprova.',
          uncertain: writing);
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<OwnedCard> holding(String uid, String id) async {
    final data = await _request(uid, 'GET', '/api/marketplace-collection');
    if (data['uid'] != uid || data['items'] is! List) {
      throw const CollectionSwitchFailure(
          'Collezione non verificata. Aggiornala prima di continuare.');
    }
    final rows = (data['items'] as List)
        .whereType<Map<String, dynamic>>()
        .where((row) => row['id'] == id && row['uid'] == uid)
        .toList();
    if (rows.length != 1) {
      throw const CollectionSwitchFailure(
          'La copia non è più nella collezione. Aggiorna le carte.');
    }
    return OwnedCard.fromJson(rows.single);
  }

  Future<List<Map<String, dynamic>>> listings(String uid, String cardId,
      {String? id}) async {
    final data =
        await _request(uid, 'GET', '/api/marketplace-listings', query: {
      'sellerUid': uid,
      'cardId': cardId,
      'nativeOnly': '1',
      'limit': '1000',
      if (id != null) 'id': id,
    });
    if (data['listings'] is! List) {
      throw const CollectionSwitchFailure('Listing non verificati.');
    }
    final rows = <Map<String, dynamic>>[];
    for (final row in data['listings'] as List) {
      if (row is! Map<String, dynamic> ||
          row['sellerUid'] != uid ||
          '${row['cardId']}' != cardId) {
        throw const CollectionSwitchFailure(
            'Il listing non appartiene a questa collezione.');
      }
      rows.add(row);
    }
    if (rows.length >= 1000 && id == null) {
      throw const CollectionSwitchFailure(
          'Troppi listing per verificare questa copia. Usa MyPokoin.');
    }
    return rows;
  }

  Future<String> country(String uid) async {
    final data = await _request(uid, 'GET', '/api/marketplace-seller-settings');
    final country = '${data['shipFromCountry'] ?? ''}'.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country) || country == 'EU') {
      throw const CollectionSwitchFailure(
          'Imposta il paese di spedizione nel Profilo/MyPokoin prima di listare.');
    }
    return country;
  }

  Future<Map<String, dynamic>> create(
      String uid, Map<String, dynamic> body) async {
    final data =
        await _request(uid, 'POST', '/api/marketplace-listings', body: body);
    final row = data['listing'] ?? data;
    if (row is! Map<String, dynamic>) {
      throw const CollectionSwitchFailure(
          'Risposta listing incompleta. Verifica l’esito.',
          uncertain: true);
    }
    return row;
  }

  Future<void> update(
      String uid, String id, Map<String, dynamic> changes) async {
    await _request(uid, 'PATCH', '/api/marketplace-listings',
        query: {'id': id}, body: {'sellerUid': uid, ...changes});
  }
}
