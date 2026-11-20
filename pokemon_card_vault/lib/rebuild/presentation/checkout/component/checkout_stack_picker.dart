import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../model/checkout_group.dart';
import '../../../style/checkout_style.dart';
import '../../shared/atomics/marketplace_thumbnail.dart';
import '../atomics/checkout_card_stack.dart';

class CheckoutStackPicker extends StatelessWidget {
  const CheckoutStackPicker(
      {super.key,
      required this.groups,
      required this.selected,
      required this.onSelected,
      this.inspecting = false,
      this.onInspect,
      this.included,
      this.stackBuilder});
  final List<CheckoutGroup> groups;
  final CheckoutGroupKey selected;
  final ValueChanged<CheckoutGroupKey> onSelected;
  final bool inspecting;
  final ValueChanged<CheckoutGroupKey>? onInspect;
  final bool? included;
  final Widget Function(Widget child)? stackBuilder;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final found = groups.indexWhere((group) => group.key == selected);
    final index = found < 0 ? 0 : found;
    final current = groups[index];
    final scheme = Theme.of(context).colorScheme;
    Color accent(CheckoutGroup group) =>
        CheckoutStyle.stackAccent(scheme, group.key);
    void tapGroup(CheckoutGroupKey key) {
      if (inspecting && onInspect != null) {
        onInspect!(key);
      } else {
        onSelected(key);
      }
    }

    final stack = CheckoutCardStack(
        groups: groups,
        selected: current.key,
        colors: groups.map(accent).toList(),
        onSelected: tapGroup);
    final dotCount = math.min(groups.length, 7);
    final dotStart = (index - dotCount ~/ 2).clamp(0, groups.length - dotCount);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      stackBuilder?.call(stack) ?? stack,
      const SizedBox(height: 8),
      OutlinedButton(
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: accent(current), width: 2),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(12)),
          onPressed: () => tapGroup(current.key),
          child: Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: MarketplaceThumbnail(
                    imageUrl: current.offers.first.card.imageUrl,
                    width: 40,
                    height: 56)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    '${current.offers.first.card.name} · ${current.key.condition}\n'
                    '${current.quantity} ${current.quantity == 1 ? 'copia' : 'copie'} · ${current.key.language}')),
            const SizedBox(width: 8),
            Icon(
                included == true
                    ? Icons.check_circle
                    : included == false
                        ? Icons.circle_outlined
                        : Icons.remove_circle_outline,
                color: scheme.primary),
          ])),
      const SizedBox(height: 8),
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
      if (dotCount > 1)
        ExcludeSemantics(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var dot = dotStart; dot < dotStart + dotCount; dot++)
            Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                width: dot == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                    color:
                        dot == index ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4))),
        ])),
    ]);
  }
}
