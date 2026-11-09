import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../model/portfolio_history.dart';
import 'account_api_provider.dart';

class PortfolioHistoryProvider {
  PortfolioHistoryProvider(
      {FirebaseAuth? auth,
      http.Client? client,
      Future<String?> Function(String uid)? idToken})
      : _api = AccountApiProvider(auth: auth, client: client, idToken: idToken);
  final AccountApiProvider _api;

  Future<List<PortfolioHistoryPoint>> fetch(String uid) async {
    final payload = await _api.get(uid, '/api/marketplace-portfolio-history');
    if ((payload['uid'] != null && payload['uid'] != uid) ||
        payload['days'] is! List) {
      throw const FormatException('Invalid private portfolio history');
    }
    return List.unmodifiable((payload['days'] as List).map((row) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid portfolio history day');
      }
      return PortfolioHistoryPoint.fromJson(row);
    }));
  }
}
