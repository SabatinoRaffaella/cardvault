/// Valutazioni giornaliere reali della dashboard, espresse in PKN.
class PortfolioHistoryPoint {
  const PortfolioHistoryPoint(
      {required this.date,
      required this.currencyPkn,
      this.cardsValuePkn,
      this.cardsHeld = 0,
      this.cardsPriced = 0});

  factory PortfolioHistoryPoint.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] is Map ? json['assets'] as Map : const {};
    final date = DateTime.tryParse('${json['date'] ?? json['day'] ?? ''}');
    if (date == null) throw const FormatException('Invalid portfolio date');
    double amount(Object? value) {
      final number = value == null ? 0.0 : double.tryParse('$value');
      if (number == null || !number.isFinite || number < 0) {
        throw const FormatException('Invalid portfolio value');
      }
      return number;
    }

    final rawCards = json.containsKey('cardsValuePkn')
        ? json['cardsValuePkn']
        : assets['cardsValuePkn'];
    final known = (json['cardsKnown'] ?? assets['cardsKnown']) == true;
    return PortfolioHistoryPoint(
        date: DateTime.utc(date.year, date.month, date.day),
        currencyPkn: amount(
            json['currencyPkn'] ?? json['currency'] ?? assets['currencyPkn']),
        cardsValuePkn: known && rawCards != null && rawCards != ''
            ? amount(rawCards)
            : null,
        cardsHeld: amount(json['cardsHeld'] ?? assets['cardsHeld']).toInt(),
        cardsPriced:
            amount(json['cardsPriced'] ?? assets['cardsPriced']).toInt());
  }

  final DateTime date;
  final double currencyPkn;
  final double? cardsValuePkn;
  final int cardsHeld, cardsPriced;
  double get totalPkn => currencyPkn + (cardsValuePkn ?? 0);
}

enum PortfolioPeriod {
  month('1M', 30),
  quarter('3M', 91),
  halfYear('6M', 182),
  year('1A', 365),
  all('Tutto', null);

  const PortfolioPeriod(this.label, this.days);
  final String label;
  final int? days;
}
