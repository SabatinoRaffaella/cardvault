import 'package:flutter/material.dart';
import '../../../controller/checkout_controller.dart';
import '../../../model/checkout_group.dart';
import '../../../style/checkout_style.dart';
import '../../shared/atomics/marketplace_thumbnail.dart';
import '../../shared/price_format.dart';
import '../atomics/offer_selector.dart';
import 'checkout_offer_details.dart';

class CheckoutGroupCard extends StatefulWidget {
  const CheckoutGroupCard(
      {super.key,
      required this.group,
      required this.controller,
      this.showArtwork = true,
      this.initiallyExpanded = false});
  final CheckoutGroup group;
  final CheckoutController controller;
  final bool showArtwork, initiallyExpanded;
  @override
  State<CheckoutGroupCard> createState() => _CheckoutGroupCardState();
}

class _CheckoutGroupCardState extends State<CheckoutGroupCard> {
  late bool _expanded;
  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final controller = widget.controller;
    final card = group.offers.first.card;
    final offer = controller.activeOffer(group);
    final index =
        group.offers.indexWhere((item) => item.listing.id == offer.listing.id);
    final selected = controller.selectionFor(group);
    final colors = Theme.of(context).colorScheme;
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${group.quantity} × ${card.name}',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text([group.key.condition, group.key.language]
          .where((v) => v.isNotEmpty)
          .join(' · ')),
      Text(
          [card.expansion, card.number].where((v) => v.isNotEmpty).join(' · ')),
      if (offer.listing.attributes.isNotEmpty)
        Text(offer.listing.attributes.join(' · ')),
      const SizedBox(height: 8),
      Text(pknPrice(group.totalPkn),
          style: Theme.of(context).textTheme.titleLarge),
      Text(
          '${group.offers.length} offerte · ${controller.selectedIn(group)} copie selezionate'),
    ]);
    return DecoratedBox(
      decoration: CheckoutStyle.panel(colors,
          selected: selected != false,
          accent: CheckoutStyle.stackAccent(colors, group.key)),
      child: Padding(
          padding: CheckoutStyle.panelPadding,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Checkbox(
                  tristate: true,
                  value: selected,
                  semanticLabel: 'Seleziona gruppo ${card.name}',
                  onChanged: controller.cart.canEdit
                      ? (_) => controller.selectGroup(group, selected != true)
                      : null),
              const Expanded(child: Text('Gruppo carte')),
              IconButton(
                  tooltip: _expanded ? 'Nascondi offerte' : 'Mostra offerte',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon:
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more)),
            ]),
            InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: CheckoutStyle.radius,
                child: LayoutBuilder(builder: (context, constraints) {
                  if (!widget.showArtwork) return details;
                  final image = Semantics(
                      label: card.name,
                      image: true,
                      child: MarketplaceThumbnail(
                          imageUrl: card.imageUrl, width: 82, height: 115));
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [image, const SizedBox(height: 12), details]);
                  }
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        image,
                        const SizedBox(width: 16),
                        Expanded(child: details)
                      ]);
                })),
            if (_expanded) ...[
              const Padding(
                  padding: EdgeInsets.only(top: 12), child: Divider()),
              OfferSelector(
                  index: index,
                  count: group.offers.length,
                  onPrevious: index > 0
                      ? () => controller.selectOffer(
                          group, group.offers[index - 1].listing.id)
                      : null,
                  onNext: index < group.offers.length - 1
                      ? () => controller.selectOffer(
                          group, group.offers[index + 1].listing.id)
                      : null),
              CheckoutOfferDetails(
                  key: ValueKey(offer.listing.id),
                  item: offer,
                  selected: controller.selectedQuantity(offer.listing.id),
                  editable: controller.cart.canEdit,
                  onSelectionChanged: (value) =>
                      controller.setSelectedQuantity(offer.listing.id, value),
                  onRemoveCopy: () => controller.removeCopy(offer.listing.id),
                  onRemoveOffer: () =>
                      controller.removeOffer(offer.listing.id)),
            ] else
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                      onPressed: () => setState(() => _expanded = true),
                      child: const Text('Vedi offerte e venditori'))),
          ])),
    );
  }
}
