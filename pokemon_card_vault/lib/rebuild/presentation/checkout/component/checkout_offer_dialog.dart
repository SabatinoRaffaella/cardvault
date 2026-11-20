import 'package:flutter/material.dart';
import '../../../controller/checkout_controller.dart';
import '../../../model/checkout_group.dart';
import '../../../style/checkout_style.dart';
import '../../shared/price_format.dart';
import '../atomics/checkout_group_button.dart';
import '../atomics/offer_selector.dart';
import 'checkout_offer_details.dart';

class CheckoutOfferDialog extends StatelessWidget {
  const CheckoutOfferDialog(
      {super.key,
      required this.controller,
      required this.pileId,
      required this.onRemoveCopy,
      required this.onUndo});
  final CheckoutController controller;
  final String pileId;
  final ValueChanged<String> onRemoveCopy;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) => Theme(
      data: CheckoutStyle.theme(Theme.of(context)),
      child: Builder(builder: _buildDialog));

  Widget _buildDialog(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        CheckoutPile? pile;
        for (final candidate in controller.piles) {
          if (candidate.id == pileId) {
            pile = candidate;
            break;
          }
        }
        final group = pile == null ? null : controller.activeGroup(pile);
        final offer = group == null ? null : controller.activeOffer(group);
        final index = group?.offers
                .indexWhere((row) => row.listing.id == offer?.listing.id) ??
            0;
        final colors = Theme.of(context).colorScheme;
        final selected = group == null ? false : controller.selectionFor(group);
        return Dialog(
            backgroundColor: colors.surface,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
                borderRadius: CheckoutStyle.radius,
                side: BorderSide(color: colors.outlineVariant)),
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 440,
                    maxHeight: MediaQuery.sizeOf(context).height * .82),
                child: Padding(
                    padding: CheckoutStyle.panelPadding,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text('Offerte del gruppo',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                            IconButton(
                                tooltip: 'Chiudi dettagli',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close)),
                          ]),
                          const SizedBox(height: 8),
                          Flexible(
                              child: SingleChildScrollView(
                                  child: group == null ||
                                          offer == null ||
                                          pile == null
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 20),
                                          child: Text('Il bundle è vuoto.'))
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                              CheckoutGroupButton(
                                                  groups: pile.groups,
                                                  selected: group,
                                                  onSelected: (key) =>
                                                      controller
                                                          .selectPileGroup(
                                                              pile!, key)),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                  alignment: WrapAlignment
                                                      .spaceBetween,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  spacing: 8,
                                                  children: [
                                                    Text(
                                                        '${group.quantity} copie · ${pknPrice(group.totalPkn)}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall),
                                                    TextButton.icon(
                                                        onPressed: controller
                                                                .cart.canEdit
                                                            ? () => controller
                                                                .selectGroup(
                                                                    group,
                                                                    selected !=
                                                                        true)
                                                            : null,
                                                        icon: Icon(
                                                            selected == true
                                                                ? Icons
                                                                    .check_circle
                                                                : selected ==
                                                                        null
                                                                    ? Icons
                                                                        .indeterminate_check_box_outlined
                                                                    : Icons
                                                                        .circle_outlined,
                                                            size: 18),
                                                        label: Text(selected ==
                                                                true
                                                            ? 'Gruppo selezionato'
                                                            : 'Seleziona gruppo')),
                                                  ]),
                                              if (group.offers.length > 1)
                                                OfferSelector(
                                                    index: index,
                                                    count: group.offers.length,
                                                    onPrevious: index > 0
                                                        ? () => controller
                                                            .selectOffer(
                                                                group,
                                                                group
                                                                    .offers[
                                                                        index -
                                                                            1]
                                                                    .listing
                                                                    .id)
                                                        : null,
                                                    onNext: index <
                                                            group.offers.length -
                                                                1
                                                        ? () => controller
                                                            .selectOffer(
                                                                group,
                                                                group
                                                                    .offers[
                                                                        index +
                                                                            1]
                                                                    .listing
                                                                    .id)
                                                        : null),
                                              if (group.offers.length == 1)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 8),
                                                    child: Text(
                                                        'Offerta 1 di 1',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall)),
                                              CheckoutOfferDetails(
                                                  key: ValueKey(
                                                      offer.listing.id),
                                                  item: offer,
                                                  selected: controller
                                                      .selectedQuantity(
                                                          offer.listing.id),
                                                  editable:
                                                      controller.cart.canEdit,
                                                  onSelectionChanged: (n) =>
                                                      controller
                                                          .setSelectedQuantity(
                                                              offer.listing.id,
                                                              n),
                                                  onRemoveCopy: () =>
                                                      onRemoveCopy(
                                                          offer.listing.id),
                                                  onRemoveOffer: () =>
                                                      controller.removeOffer(
                                                          offer.listing.id),
                                                  showRemoveOffer: false),
                                            ]))),
                          const SizedBox(height: 12),
                          Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (controller.canUndo)
                                  TextButton.icon(
                                      onPressed: onUndo,
                                      icon: const Icon(Icons.undo, size: 20),
                                      label: const Text(
                                          'Annulla ultima rimozione')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Chiudi')),
                              ]),
                        ]))));
      });
}
