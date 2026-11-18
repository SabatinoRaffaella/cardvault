import 'package:flutter/material.dart';
import '../../../model/cart_item.dart';
import '../../shared/price_format.dart';

class CheckoutOfferDetails extends StatelessWidget {
  const CheckoutOfferDetails(
      {super.key,
      required this.item,
      required this.selected,
      required this.editable,
      required this.onSelectionChanged,
      required this.onRemoveCopy,
      required this.onRemoveOffer,
      this.showRemoveOffer = true});
  final ListingCartItem item;
  final int selected;
  final bool editable;
  final ValueChanged<int> onSelectionChanged;
  final VoidCallback onRemoveCopy, onRemoveOffer;
  final bool showRemoveOffer;

  @override
  Widget build(BuildContext context) {
    final listing = item.listing;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(listing.sellerName, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text([
        listing.origin.label,
        if (listing.country.isNotEmpty) listing.country
      ].join(' · ')),
      const SizedBox(height: 8),
      Text('${pknPrice(listing.pricePkn)} per copia'),
      Text(
          'Nel carrello: ${item.quantity} · Totale offerta: ${pknPrice(item.totalPkn)}'),
      if (listing.comment.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(listing.comment)),
      if (!listing.isAvailable || item.quantity > listing.stock)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Disponibilità da riconfermare.')),
      const SizedBox(height: 8),
      Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Checkbox(
                tristate: true,
                semanticLabel: 'Seleziona offerta di ${listing.sellerName}',
                value: selected == 0
                    ? false
                    : selected == item.quantity
                        ? true
                        : null,
                onChanged: editable
                    ? (_) => onSelectionChanged(
                        selected == item.quantity ? 0 : item.quantity)
                    : null),
            const Text('Copie da includere'),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  tooltip: 'Seleziona una copia in meno',
                  onPressed: editable && selected > 0
                      ? () => onSelectionChanged(selected - 1)
                      : null,
                  icon: const Icon(Icons.remove)),
              Text('$selected / ${item.quantity}'),
              IconButton(
                  tooltip: 'Seleziona una copia in più',
                  onPressed: editable && selected < item.quantity
                      ? () => onSelectionChanged(selected + 1)
                      : null,
                  icon: const Icon(Icons.add)),
            ]),
          ]),
      Wrap(spacing: 8, runSpacing: 4, children: [
        TextButton.icon(
            onPressed: editable ? onRemoveCopy : null,
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Rimuovi una copia')),
        if (showRemoveOffer)
          TextButton.icon(
              onPressed: editable ? onRemoveOffer : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Rimuovi offerta')),
      ]),
    ]);
  }
}
