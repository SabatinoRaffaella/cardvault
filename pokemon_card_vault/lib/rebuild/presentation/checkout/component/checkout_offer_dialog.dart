import 'package:flutter/material.dart';
import '../../../controller/checkout_controller.dart';
import '../../../model/checkout_group.dart';
import '../../../style/checkout_style.dart';
import '../../shared/price_format.dart';
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
  Widget build(BuildContext context) => ListenableBuilder(
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
        return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: const RoundedRectangleBorder(
                borderRadius: CheckoutStyle.radius),
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: MediaQuery.sizeOf(context).height * .82),
                child: Padding(
                    padding: CheckoutStyle.panelPadding,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text('Dettagli bundle',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                            IconButton(
                                tooltip: 'Chiudi dettagli',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close)),
                          ]),
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
                                              InputDecorator(
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText:
                                                              'Gruppo nel bundle'),
                                                  child:
                                                      DropdownButtonHideUnderline(
                                                          child: DropdownButton<
                                                                  CheckoutGroupKey>(
                                                              value: group.key,
                                                              isExpanded: true,
                                                              itemHeight: null,
                                                              items: [
                                                                for (final entry
                                                                    in pile
                                                                        .groups)
                                                                  DropdownMenuItem(
                                                                      value: entry
                                                                          .key,
                                                                      child: Padding(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              vertical:
                                                                                  8),
                                                                          child: Text(
                                                                              '${entry.offers.first.card.name} · ${entry.key.condition} · ${entry.key.language}',
                                                                              maxLines: 2,
                                                                              overflow: TextOverflow.ellipsis)))
                                                              ],
                                                              onChanged: (key) {
                                                                if (key !=
                                                                    null) {
                                                                  controller
                                                                      .selectPileGroup(
                                                                          pile!,
                                                                          key);
                                                                }
                                                              }))),
                                              CheckboxListTile(
                                                  contentPadding: EdgeInsets
                                                      .zero,
                                                  tristate: true,
                                                  value: controller
                                                      .selectionFor(group),
                                                  onChanged: controller
                                                          .cart.canEdit
                                                      ? (_) =>
                                                          controller.selectGroup(
                                                              group,
                                                              controller.selectionFor(
                                                                      group) !=
                                                                  true)
                                                      : null,
                                                  title: const Text(
                                                      'Seleziona questo gruppo'),
                                                  subtitle: Text(
                                                      '${group.quantity} copie · ${pknPrice(group.totalPkn)}'),
                                                  activeColor:
                                                      CheckoutStyle.stackAccent(
                                                          colors, group.key)),
                                              OfferSelector(
                                                  index: index,
                                                  count: group.offers.length,
                                                  onPrevious: index > 0
                                                      ? () => controller
                                                          .selectOffer(
                                                              group,
                                                              group
                                                                  .offers[
                                                                      index - 1]
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
                                                                      index + 1]
                                                                  .listing
                                                                  .id)
                                                      : null),
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
                          const SizedBox(height: 8),
                          if (controller.canUndo)
                            TextButton.icon(
                                onPressed: onUndo,
                                icon: const Icon(Icons.undo),
                                label: const Text('Annulla ultima rimozione')),
                          FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Chiudi')),
                        ]))));
      });
}
