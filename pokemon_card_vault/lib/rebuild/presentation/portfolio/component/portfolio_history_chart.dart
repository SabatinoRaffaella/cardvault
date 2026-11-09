import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/portfolio_history.dart';
import '../../../style/portfolio_style.dart';
import '../../shared/price_format.dart';

class PortfolioHistoryChart extends StatefulWidget {
  const PortfolioHistoryChart({super.key, required this.points});
  final List<PortfolioHistoryPoint> points;
  @override
  State<PortfolioHistoryChart> createState() => _PortfolioHistoryChartState();
}

class _PortfolioHistoryChartState extends State<PortfolioHistoryChart> {
  int? _selected;
  @override
  void didUpdateWidget(PortfolioHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _selected = null;
  }

  void _select(double x, double width) {
    if (width <= 0 || widget.points.isEmpty) return;
    final first = widget.points.first.date.millisecondsSinceEpoch;
    final span = widget.points.last.date.millisecondsSinceEpoch - first;
    final target = first + x.clamp(0, width) / width * span;
    var closest = 0;
    for (var i = 1; i < widget.points.length; i++) {
      if ((widget.points[i].date.millisecondsSinceEpoch - target).abs() <
          (widget.points[closest].date.millisecondsSinceEpoch - target).abs()) {
        closest = i;
      }
    }
    setState(() => _selected = closest);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();
    final selected = points[_selected ?? points.length - 1];
    final max = points.fold<double>(
        0, (value, point) => point.totalPkn > value ? point.totalPkn : value);
    final ceiling = max > 0 ? max * 1.08 : 1.0;
    final date = DateFormat('dd/MM/yyyy');
    final compact = NumberFormat.compact(locale: 'it_IT');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 48,
            height: PortfolioStyle.chartHeight,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 4; i >= 0; i--)
                    Text(compact.format(ceiling * i / 4),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall)
                ])),
        Expanded(
            child: LayoutBuilder(
                builder: (context, constraints) => Semantics(
                    label: 'Valore del patrimonio in PKN. '
                        '${date.format(selected.date)}: ${pknPrice(selected.totalPkn)}',
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _select(
                            details.localPosition.dx, constraints.maxWidth),
                        onHorizontalDragUpdate: (details) => _select(
                            details.localPosition.dx, constraints.maxWidth),
                        child: SizedBox(
                            height: PortfolioStyle.chartHeight,
                            child: CustomPaint(
                                painter: _HistoryPainter(
                                    points: points,
                                    ceiling: ceiling,
                                    selected: _selected,
                                    grid: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant))))))),
      ]),
      const SizedBox(height: 8),
      Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              children: [
                Text(date.format(points.first.date)),
                if (points.length > 1) Text(date.format(points.last.date))
              ])),
      const SizedBox(height: 16),
      Text(date.format(selected.date),
          style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      _valueRow(context, 'Totale', pknPrice(selected.totalPkn)),
      _valueRow(
          context,
          'Carte',
          selected.cardsValuePkn == null
              ? 'Valore non disponibile'
              : pknPrice(selected.cardsValuePkn!),
          PortfolioStyle.cards),
      _valueRow(context, 'Liquidità', pknPrice(selected.currencyPkn),
          PortfolioStyle.liquidity),
      if (selected.cardsValuePkn != null && selected.cardsHeld > 0)
        Text(
            '${selected.cardsPriced} di ${selected.cardsHeld} copie con un prezzo di vendita registrato.',
            style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Text(
          points.length == 1
              ? 'Una sola rilevazione disponibile.'
              : 'Tocca il grafico per leggere una rilevazione.',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Widget _valueRow(BuildContext context, String label, String value,
          [Color? color]) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (color != null) ...[
              Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: DecoratedBox(
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                      child: const SizedBox(width: 8, height: 8))),
              const SizedBox(width: 6)
            ],
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]));
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(
      {required this.points,
      required this.ceiling,
      required this.grid,
      this.selected});
  final List<PortfolioHistoryPoint> points;
  final double ceiling;
  final Color grid;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final floor = size.height - 4;
    double y(double value) => floor - value / ceiling * (size.height - 8);
    final start = points.first.date.millisecondsSinceEpoch;
    final span = points.last.date.millisecondsSinceEpoch - start;
    double x(PortfolioHistoryPoint point) => span == 0
        ? size.width / 2
        : 4 +
            (point.date.millisecondsSinceEpoch - start) /
                span *
                (size.width - 8);
    final rule = Paint()
      ..color = grid
      ..strokeWidth = .7;
    for (var i = 0; i < 5; i++) {
      final lineY = floor - (size.height - 8) * i / 4;
      canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), rule);
    }
    Path step(double Function(PortfolioHistoryPoint) value) {
      final path = Path()..moveTo(x(points.first), y(value(points.first)));
      for (var i = 1; i < points.length; i++) {
        path.lineTo(x(points[i]), y(value(points[i - 1])));
        path.lineTo(x(points[i]), y(value(points[i])));
      }
      return path;
    }

    final total = step((point) => point.totalPkn);
    final currency = step((point) => point.currencyPkn);
    final area = Path.from(total)
      ..lineTo(x(points.last), floor)
      ..lineTo(x(points.first), floor)
      ..close();
    canvas.drawPath(
        area, Paint()..color = PortfolioStyle.cards.withValues(alpha: .14));
    final liquidArea = Path.from(currency)
      ..lineTo(x(points.last), floor)
      ..lineTo(x(points.first), floor)
      ..close();
    canvas.drawPath(liquidArea,
        Paint()..color = PortfolioStyle.liquidity.withValues(alpha: .22));
    canvas.drawPath(
        currency,
        Paint()
          ..color = PortfolioStyle.liquidity
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);
    canvas.drawPath(
        total,
        Paint()
          ..color = PortfolioStyle.cards
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    final point = points[selected ?? points.length - 1];
    if (selected != null) {
      canvas.drawLine(Offset(x(point), 0), Offset(x(point), floor), rule);
    }
    canvas.drawCircle(Offset(x(point), y(point.totalPkn)), 4,
        Paint()..color = PortfolioStyle.cards);
  }

  @override
  bool shouldRepaint(_HistoryPainter oldDelegate) =>
      points != oldDelegate.points ||
      selected != oldDelegate.selected ||
      ceiling != oldDelegate.ceiling ||
      grid != oldDelegate.grid;
}
