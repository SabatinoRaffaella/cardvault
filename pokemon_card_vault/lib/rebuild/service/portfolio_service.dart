import '../model/portfolio_history.dart';
import '../model/cardex.dart';
import '../provider/portfolio_history_provider.dart';
import 'card_ownership_service.dart';

class PortfolioService {
  PortfolioService({PortfolioHistoryProvider? provider})
      : _provider = provider ?? PortfolioHistoryProvider();
  final PortfolioHistoryProvider _provider;

  static CardCollection listedCollection(CardCollection collection) =>
      CardCollection(status: collection.status, items: collection.listedItems);

  static double? priceFor(CardCollection collection, String cardId,
      {String? language}) {
    const ownership = CardOwnershipService();
    double? minimum;
    for (final item in collection.listedItems) {
      if (item.card.id != cardId ||
          (language != null &&
              ownership.normalizeLanguage(item.language) != language)) {
        continue;
      }
      final price = item.card.pricePkn;
      if (price != null && (minimum == null || price < minimum)) {
        minimum = price;
      }
    }
    return minimum;
  }

  Future<List<PortfolioHistoryPoint>> loadHistory(String uid) async {
    final days = await _provider.fetch(uid);
    final unique = {for (final day in days) day.date: day};
    return List.unmodifiable(
        unique.values.toList()..sort((a, b) => a.date.compareTo(b.date)));
  }

  List<PortfolioHistoryPoint> inPeriod(
      List<PortfolioHistoryPoint> history, PortfolioPeriod period) {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final from = period.days == null
        ? null
        : today.subtract(Duration(days: period.days!));
    return List.unmodifiable(history.where((point) =>
        !point.date.isAfter(today) &&
        (from == null || !point.date.isBefore(from))));
  }
}
