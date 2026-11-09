import 'dart:async';
import 'package:flutter/material.dart';
import '../../../controller/portfolio_controller.dart';
import '../../../model/portfolio_history.dart';
import 'portfolio_history_chart.dart';

class PortfolioHistoryDrawer extends StatelessWidget {
  const PortfolioHistoryDrawer(
      {super.key, required this.controller, required this.onClose});
  final PortfolioController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Andamento del Portfolio',
      child: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Andamento del valore',
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          onPressed: onClose,
                          tooltip: 'Chiudi grafico',
                          icon: const Icon(Icons.close))
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                        'Carte e liquidità, come nella dashboard Pokoin.'),
                    const SizedBox(height: 8),
                    Text(
                        'Lo storico riguarda il patrimonio complessivo, incluse le carte fuori vendita.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 20),
                    if (!controller.signedIn)
                      const Text(
                          'Accedi al tuo account per vedere lo storico del Portfolio.')
                    else ...[
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final period in PortfolioPeriod.values)
                          ChoiceChip(
                              label: Text(period.label),
                              selected: controller.period == period,
                              onSelected: (_) =>
                                  controller.selectPeriod(period))
                      ]),
                      const SizedBox(height: 20),
                      if (controller.loading) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text('Caricamento dello storico…'),
                      ],
                      if (controller.failed) ...[
                        const Text(
                            'Lo storico non è disponibile. Riprova tra poco.'),
                        TextButton.icon(
                            onPressed: () => unawaited(
                                controller.loadHistory(forceRefresh: true)),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Riprova')),
                      ],
                      if (controller.visibleHistory.isNotEmpty)
                        PortfolioHistoryChart(points: controller.visibleHistory)
                      else if (!controller.loading && !controller.failed)
                        Text(controller.history.isEmpty
                            ? 'Non ci sono ancora rilevazioni nello storico.'
                            : 'Nessuna rilevazione in questo periodo. Scegli Tutto per vedere lo storico disponibile.'),
                      const SizedBox(height: 16),
                      if (!controller.loading && !controller.failed)
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                                onPressed: () => unawaited(
                                    controller.loadHistory(forceRefresh: true)),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Aggiorna storico'))),
                    ],
                  ]))));
}
