import 'package:flutter/material.dart';
import '../../controller/cart_controller.dart';
import '../../controller/checkout_controller.dart';
import '../../model/checkout_group.dart';
import '../../style/checkout_style.dart';
import '../shared/component/themed_page_background.dart';
import '../shared/component/utility_bar.dart';
import '../shared/price_format.dart';
import 'component/checkout_pile_card.dart';
import 'component/checkout_offer_dialog.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen(
      {super.key,
      required this.cart,
      this.onDestinationSelected,
      this.navigationIndex = 0});
  final CartController cart;
  final ValueChanged<int>? onDestinationSelected;
  final int navigationIndex;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late CheckoutController _controller;
  String? _activePileId;
  int _switchDirection = 1;
  @override
  void initState() {
    super.initState();
    _controller = CheckoutController(widget.cart);
  }

  @override
  void didUpdateWidget(CheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cart != widget.cart) {
      _controller.dispose();
      _controller = CheckoutController(widget.cart);
      _activePileId = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchBundle(int direction) {
    final piles = _controller.piles;
    if (piles.isEmpty) return;
    final found = piles.indexWhere((pile) => pile.id == _activePileId);
    final index = found < 0 ? 0 : found;
    final next = index + direction;
    if (next < 0 || next >= piles.length) return;
    setState(() {
      _activePileId = piles[next].id;
      _switchDirection = direction;
    });
  }

  void _removeCopy(String id) {
    if (!_controller.removeCopy(id) || !mounted) return;
    final name = _controller.removedItem?.card.name ?? 'carta';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('Rimossa una copia di $name'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(label: 'Annulla', onPressed: _undo)));
  }

  void _undo() {
    if (!mounted) return;
    final removed = _controller.removedItem;
    final restored = _controller.undoRemoval();
    if (restored && removed != null) {
      for (final pile in _controller.piles) {
        if (pile.groups.any((group) =>
            group.offers.any((row) => row.listing.id == removed.listing.id))) {
          setState(() => _activePileId = pile.id);
          break;
        }
      }
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (!restored) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La rimozione non può più essere annullata.')));
    }
  }

  void _openGroup(CheckoutPile pile, CheckoutGroupKey key) {
    _controller.selectPileGroup(pile, key);
    showDialog<void>(
        context: context,
        builder: (_) => CheckoutOfferDialog(
            controller: _controller,
            pileId: pile.id,
            onRemoveCopy: _removeCopy,
            onUndo: _undo));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final cart = widget.cart;
        final groups = _controller.groups;
        final piles = _controller.piles;
        final index = piles.indexWhere((pile) => pile.id == _activePileId);
        final activeIndex = index < 0 ? 0 : index;
        return Scaffold(
          appBar: AppBar(title: const Text('Checkout'), actions: [
            if (_controller.canUndo)
              IconButton(
                  tooltip: 'Annulla ultima rimozione',
                  onPressed: _undo,
                  icon: const Icon(Icons.undo)),
          ]),
          body: ThemedPageBackground(
              child: SafeArea(
                  top: false,
                  child: ListView(
                    padding: CheckoutStyle.pagePadding,
                    children: [
                      Text('Carrello',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                          '${groups.fold<int>(0, (n, g) => n + g.quantity)} carte · ${groups.length} gruppi'),
                      if (cart.isLoading)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: LinearProgressIndicator()),
                      if (cart.error != null) ...[
                        Text(cart.error!),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                                onPressed: cart.retry,
                                child: const Text('Riprova carrello'))),
                      ],
                      if (groups.isEmpty && !cart.isLoading && cart.canEdit)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('Non ci sono offerte nel carrello.')),
                      if (groups.isNotEmpty) ...[
                        Wrap(spacing: 12, children: [
                          TextButton(
                              onPressed: cart.canEdit
                                  ? () => _controller.selectAll(true)
                                  : null,
                              child: const Text('Seleziona tutto')),
                          TextButton(
                              onPressed: cart.canEdit
                                  ? () => _controller.selectAll(false)
                                  : null,
                              child: const Text('Deseleziona tutto')),
                        ]),
                        Row(children: [
                          IconButton(
                              tooltip: 'Bundle precedente',
                              onPressed: activeIndex > 0
                                  ? () => _switchBundle(-1)
                                  : null,
                              icon: const Icon(Icons.chevron_left)),
                          Expanded(
                              child: Text(
                                  'Bundle ${activeIndex + 1} di ${piles.length}',
                                  textAlign: TextAlign.center)),
                          IconButton(
                              tooltip: 'Bundle successivo',
                              onPressed: activeIndex < piles.length - 1
                                  ? () => _switchBundle(1)
                                  : null,
                              icon: const Icon(Icons.chevron_right)),
                        ]),
                        AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) =>
                                SlideTransition(
                                    position: Tween<Offset>(
                                            begin: Offset(
                                                .10 * _switchDirection, 0),
                                            end: Offset.zero)
                                        .animate(animation),
                                    child: FadeTransition(
                                        opacity: animation, child: child)),
                            child: CheckoutPileCard(
                                key: ValueKey(piles[activeIndex].id),
                                pile: piles[activeIndex],
                                controller: _controller,
                                onOpenGroup: (key) =>
                                    _openGroup(piles[activeIndex], key),
                                onRemoveCopy: _removeCopy,
                                onNext: activeIndex < piles.length - 1
                                    ? () => _switchBundle(1)
                                    : null,
                                onPrevious: activeIndex > 0
                                    ? () => _switchBundle(-1)
                                    : null)),
                        const SizedBox(height: 20),
                        DecoratedBox(
                            decoration: CheckoutStyle.panel(
                                Theme.of(context).colorScheme,
                                selected: false),
                            child: Padding(
                                padding: CheckoutStyle.panelPadding,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                          '${_controller.selectedCount} copie selezionate'),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Totale carte: ${pknPrice(_controller.selectedTotalPkn)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: 12),
                                      const Text(
                                          'Spedizione e totale finale da confermare per venditore.'),
                                      const SizedBox(height: 8),
                                      const Text(
                                          'Questo riepilogo non effettua acquisti. Il pagamento non è ancora disponibile.'),
                                    ]))),
                      ],
                    ],
                  ))),
          bottomNavigationBar: widget.onDestinationSelected == null
              ? null
              : UtilityBar(
                  selectedIndex: widget.navigationIndex,
                  onDestinationSelected: widget.onDestinationSelected!),
        );
      });
}
