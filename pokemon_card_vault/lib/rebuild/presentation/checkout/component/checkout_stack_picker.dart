import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../model/checkout_group.dart';
import '../../../style/checkout_style.dart';
import '../atomics/checkout_card_stack.dart';

class CheckoutStackPicker extends StatelessWidget {
  const CheckoutStackPicker(
      {super.key,
      required this.groups,
      required this.selected,
      required this.onSelected,
      this.stackBuilder});
  final List<CheckoutGroup> groups;
  final CheckoutGroupKey selected;
  final ValueChanged<CheckoutGroupKey> onSelected;
  final Widget Function(Widget child)? stackBuilder;

  @override
  Widget build(BuildContext context) {
    final index = groups.indexWhere((group) => group.key == selected);
    final visible = List.generate(
        math.min(groups.length, 3), (i) => groups[(index + i) % groups.length]);
    final scheme = Theme.of(context).colorScheme;
    Color accent(CheckoutGroup group) =>
        CheckoutStyle.stackAccent(scheme, group.key);
    final current = groups[index];
    final stack = CheckoutCardStack(
        groups: visible,
        colors: visible.map(accent).toList(),
        onSelected: onSelected);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${current.offers.first.card.name} · ${current.key.condition}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      stackBuilder?.call(stack) ?? stack,
      const SizedBox(height: 8),
      for (final group in visible)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: accent(group), width: group.key == selected ? 2 : 1),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(12)),
            onPressed: () => onSelected(group.key),
            child: Row(children: [
              Container(width: 5, height: 30, color: accent(group)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      '${group.offers.first.card.name} · ${group.key.condition}\n'
                      '${group.quantity} copie · ${group.key.language}')),
              if (group.key == selected) const Icon(Icons.check_circle_outline),
            ]),
          ),
        ),
      Row(children: [
        IconButton(
            tooltip: 'Gruppo precedente',
            onPressed:
                index > 0 ? () => onSelected(groups[index - 1].key) : null,
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Text('Gruppo ${index + 1} di ${groups.length}',
                textAlign: TextAlign.center)),
        IconButton(
            tooltip: 'Gruppo successivo',
            onPressed: index < groups.length - 1
                ? () => onSelected(groups[index + 1].key)
                : null,
            icon: const Icon(Icons.chevron_right)),
      ]),
    ]);
  }
}
