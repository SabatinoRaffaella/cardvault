import 'package:flutter/material.dart';
import '../../../controller/checkout_controller.dart';
import '../../../model/checkout_group.dart';
import '../atomics/checkout_bundle_gesture.dart';
import '../atomics/checkout_inspection_mode.dart';
import 'checkout_stack_picker.dart';

class CheckoutPileCard extends StatelessWidget {
  const CheckoutPileCard(
      {super.key,
      required this.pile,
      required this.controller,
      required this.onOpenGroup,
      required this.onRemoveCopy,
      this.inspecting = false,
      this.onInspectionChanged,
      this.onNext,
      this.onPrevious});
  final CheckoutPile pile;
  final CheckoutController controller;
  final ValueChanged<CheckoutGroupKey> onOpenGroup;
  final ValueChanged<String> onRemoveCopy;
  final bool inspecting;
  final ValueChanged<bool>? onInspectionChanged;
  final VoidCallback? onNext, onPrevious;

  @override
  Widget build(BuildContext context) {
    final active = controller.activeGroup(pile);
    final offer = controller.activeOffer(active);
    final groupIndex =
        pile.groups.indexWhere((group) => group.key == active.key);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(pile.name, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('${pile.quantity} carte · ${pile.groups.length} gruppi'),
      const SizedBox(height: 12),
      if (onInspectionChanged != null) ...[
        CheckoutInspectionMode(
            inspecting: inspecting, onChanged: onInspectionChanged!),
        const SizedBox(height: 12),
      ],
      CheckoutStackPicker(
          groups: pile.groups,
          selected: active.key,
          included: controller.selectionFor(active),
          onSelected: (key) => controller.selectPileGroup(pile, key),
          inspecting: inspecting,
          onInspect: onOpenGroup,
          stackBuilder: (stack) => CheckoutBundleGesture(
              key: const ValueKey('checkout-bundle-gesture'),
              targetId: '${controller.cart.sessionVersion}:${offer.listing.id}',
              onRemove: controller.cart.canEdit
                  ? () => onRemoveCopy(offer.listing.id)
                  : null,
              onNext: onNext,
              onPrevious: onPrevious,
              onBrowseNext: groupIndex < pile.groups.length - 1
                  ? () => controller.selectPileGroup(
                      pile, pile.groups[groupIndex + 1].key)
                  : onNext,
              onBrowsePrevious: groupIndex > 0
                  ? () => controller.selectPileGroup(
                      pile, pile.groups[groupIndex - 1].key)
                  : onPrevious,
              selected: controller.selectionFor(active),
              selectionLabel:
                  'Seleziona gruppo · ${active.key.condition} · ${active.key.language}',
              onToggleSelection: controller.cart.canEdit
                  ? () => controller.selectGroup(
                      active, controller.selectionFor(active) != true)
                  : null,
              child: stack)),
      TextButton.icon(
          onPressed: () => onOpenGroup(active.key),
          icon: const Icon(Icons.zoom_in),
          label: const Text('Vedi offerte e venditori')),
    ]);
  }
}
