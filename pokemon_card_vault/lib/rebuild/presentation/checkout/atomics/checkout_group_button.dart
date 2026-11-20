import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../model/checkout_group.dart';

/// Compact group picker without a form field or floating label.
class CheckoutGroupButton extends StatelessWidget {
  const CheckoutGroupButton(
      {super.key,
      required this.groups,
      required this.selected,
      required this.onSelected});
  final List<CheckoutGroup> groups;
  final CheckoutGroup selected;
  final ValueChanged<CheckoutGroupKey> onSelected;

  String _label(CheckoutGroup group) =>
      '${group.offers.first.card.name} · ${group.key.condition} · ${group.key.language}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<CheckoutGroupKey>(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        tooltip: 'Scegli gruppo',
        enabled: groups.length > 1,
        initialValue: selected.key,
        onSelected: onSelected,
        constraints: BoxConstraints(
            maxWidth: math.min(360, MediaQuery.sizeOf(context).width - 32)),
        itemBuilder: (_) => [
              for (final group in groups)
                CheckedPopupMenuItem(
                    value: group.key,
                    checked: group.key == selected.key,
                    child: Text(_label(group)))
            ],
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.layers_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_label(selected),
                      style: Theme.of(context).textTheme.titleSmall)),
              if (groups.length > 1) ...[
                const SizedBox(width: 8),
                const Icon(Icons.unfold_more, size: 20),
              ],
            ])));
  }
}
