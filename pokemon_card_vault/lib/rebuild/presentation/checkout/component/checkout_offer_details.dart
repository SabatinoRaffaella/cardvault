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
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DecoratedBox(
          decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(listing.sellerName,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                        [
                          listing.origin.label,
                          if (listing.country.isNotEmpty) listing.country
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Text('${pknPrice(listing.pricePkn)} / copia',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (item.quantity > 1)
                      Text(
                          '${item.quantity} copie · ${pknPrice(item.totalPkn)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (listing.comment.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(listing.comment)),
                    if (!listing.isAvailable || item.quantity > listing.stock)
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Disponibilità da riconfermare.')),
                  ]))),
      const SizedBox(height: 8),
      if (item.quantity == 1)
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Includi questa copia'),
            value: selected == 1,
            onChanged: editable
                ? (value) => onSelectionChanged(value == true ? 1 : 0)
                : null)
      else
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
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
      Wrap(spacing: 8, children: [
        TextButton.icon(
            onPressed: editable ? onRemoveCopy : null,
            icon: Icon(Icons.remove_circle_outline,
                size: 20, color: colors.error),
            label: Text('Rimuovi una copia',
                style: TextStyle(color: editable ? colors.error : null))),
        if (showRemoveOffer)
          TextButton.icon(
              onPressed: editable ? onRemoveOffer : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Rimuovi offerta')),
      ]),
    ]);
  }
}
