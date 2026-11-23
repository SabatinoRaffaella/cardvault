import 'package:flutter/material.dart';

/// Explicitly separates browsing groups from inspecting their offers.
class CheckoutInspectionMode extends StatelessWidget {
  const CheckoutInspectionMode(
      {super.key, required this.inspecting, required this.onChanged});
  final bool inspecting;
  final ValueChanged<bool> onChanged;

  Widget _choice(
      BuildContext context, bool value, String label, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    final selected = inspecting == value;
    final foreground = selected ? colors.onPrimary : colors.onSurface;
    return ChoiceChip(
        label: Text(label),
        avatar: Icon(icon, size: 18, color: foreground),
        labelStyle: TextStyle(color: foreground),
        selectedColor: colors.primary,
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.outlineVariant),
        selected: selected,
        onSelected: (_) => onChanged(value));
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              _choice(context, false, 'Sfoglia', Icons.layers_outlined),
              _choice(context, true, 'Lente', Icons.zoom_in),
            ]),
        const SizedBox(height: 6),
        Text(
            inspecting
                ? 'Scorri per sfogliare; tocca una carta per vedere le offerte.'
                : 'Tocca o scorri le carte per cambiare gruppo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      ]);
}
