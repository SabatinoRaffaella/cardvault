import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controller/cardex_controller.dart';
import '../../controller/portfolio_controller.dart';
import '../../model/cardex.dart';
import '../../model/marketplace_home.dart';
import '../cardex/component/album_grid.dart';
import '../cardex/component/collection_notice.dart';
import '../../style/portfolio_style.dart';
import '../shared/price_format.dart';
import 'component/portfolio_history_drawer.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen(
      {super.key,
      required this.controller,
      this.historyController,
      required this.onOpen});
  final CardexController controller;
  final ValueChanged<MarketplaceCardPreview> onOpen;
  final PortfolioController? historyController;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  bool _historyOpen = false;
  CardexController get controller => widget.controller;

  void _closeHistory() => setState(() => _historyOpen = false);

  void _toggleHistory() {
    setState(() => _historyOpen = !_historyOpen);
    if (_historyOpen) unawaited(widget.historyController?.loadHistory());
  }

  @override
  void didUpdateWidget(PortfolioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_historyOpen &&
        oldWidget.historyController != widget.historyController) {
      unawaited(widget.historyController?.loadHistory());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final collection = controller.portfolioCollection;
        final history = widget.historyController;
        return PopScope(
            canPop: !_historyOpen,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && _historyOpen) _closeHistory();
            },
            child: LayoutBuilder(
                builder: (context, constraints) => Stack(children: [
                      CustomScrollView(
                          key: const PageStorageKey('portfolio'),
                          slivers: [
                            SliverPadding(
                                padding: const EdgeInsets.all(20),
                                sliver: SliverToBoxAdapter(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('Portfolio',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineLarge),
                                      const Text(
                                          'Le tue carte in vendita su Pokoin.'),
                                      CollectionNotice(
                                          status: collection.status,
                                          onRetry: controller.retryCollection),
                                      if (collection.status ==
                                              CollectionStatus.loading &&
                                          collection.cards.isNotEmpty)
                                        Text(collection.fromCache
                                            ? '${collection.cards.length} anteprime salvate · verifica listing in corso'
                                            : '${collection.cards.length} carte in vendita caricate · sincronizzazione in corso'),
                                      if (collection.status ==
                                          CollectionStatus.ready) ...[
                                        TextButton.icon(
                                            onPressed:
                                                controller.retryCollection,
                                            icon: const Icon(Icons.refresh),
                                            label:
                                                const Text('Aggiorna listing')),
                                        const SizedBox(height: 16),
                                        Text(
                                            '${collection.cards.length} carte diverse · ${collection.copies} copie in vendita'),
                                        if (collection.items.isEmpty)
                                          const Padding(
                                              padding: EdgeInsets.only(top: 20),
                                              child: Text(
                                                  'Non hai carte con listing attivi.')),
                                      ],
                                    ]))),
                            SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                    20, 0, history == null ? 20 : 44, 24),
                                sliver: AlbumGrid(
                                    cards: collection.cards,
                                    collection: collection,
                                    ownershipFor:
                                        controller.portfolioOwnershipFor,
                                    priceLabelFor: (card) {
                                      if (collection.fromCache) {
                                        return 'Aggiornamento prezzo…';
                                      }
                                      final price =
                                          controller.portfolioPriceFor(card.id);
                                      return price == null
                                          ? 'Prezzo non disponibile'
                                          : 'Da ${pknPrice(price)}';
                                    },
                                    onLanguageSelected:
                                        controller.selectListedLanguage,
                                    onOpen: widget.onOpen)),
                          ]),
                      if (history != null) ...[
                        if (_historyOpen) ...[
                          Positioned.fill(
                              child: ModalBarrier(
                                  color: Colors.black45,
                                  dismissible: true,
                                  onDismiss: _closeHistory,
                                  semanticsLabel: 'Chiudi grafico prezzi')),
                          Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              width: math.min(PortfolioStyle.drawerWidth,
                                  math.max(0, constraints.maxWidth - 48)),
                              child: CallbackShortcuts(
                                  bindings: {
                                    const SingleActivator(
                                            LogicalKeyboardKey.escape):
                                        _closeHistory,
                                  },
                                  child: Focus(
                                      autofocus: true,
                                      child: Material(
                                          elevation: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          borderRadius:
                                              const BorderRadius.horizontal(
                                                  left: Radius.circular(20)),
                                          clipBehavior: Clip.antiAlias,
                                          child: ListenableBuilder(
                                              listenable: history,
                                              builder: (context, _) =>
                                                  PortfolioHistoryDrawer(
                                                      controller: history,
                                                      onClose:
                                                          _closeHistory)))))),
                        ],
                        Positioned(
                            right: _historyOpen
                                ? math.min(PortfolioStyle.drawerWidth,
                                    math.max(0.0, constraints.maxWidth - 48))
                                : 0,
                            top:
                                math.max(0.0, (constraints.maxHeight - 56) / 2),
                            child: Semantics(
                                button: true,
                                toggled: _historyOpen,
                                label: 'Grafico del Portfolio',
                                child: Material(
                                    elevation: 3,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh,
                                    borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(14)),
                                    child: SizedBox(
                                        width: 36,
                                        height: 56,
                                        child: IconButton(
                                            onPressed: _toggleHistory,
                                            padding: EdgeInsets.zero,
                                            tooltip: _historyOpen
                                                ? 'Chiudi grafico prezzi'
                                                : 'Apri grafico prezzi',
                                            icon: Icon(
                                                _historyOpen
                                                    ? Icons.chevron_right
                                                    : Icons.show_chart,
                                                size: 22)))))),
                      ],
                    ])));
      });
}
