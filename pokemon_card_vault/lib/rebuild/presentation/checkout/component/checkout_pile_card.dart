import 'package:flutter/material.dart';
import '../../../controller/checkout_controller.dart';
import '../../../model/checkout_group.dart';
import '../atomics/checkout_bundle_gesture.dart';
import 'checkout_stack_picker.dart';

class CheckoutPileCard extends StatelessWidget {
  const CheckoutPileCard(
      {super.key,
      required this.pile,
      required this.controller,
      required this.onOpenGroup,
      required this.onRemoveCopy,
      this.onNext,
      this.onPrevious});
  final CheckoutPile pile;
  final CheckoutController controller;
  final ValueChanged<CheckoutGroupKey> onOpenGroup;
  final ValueChanged<String> onRemoveCopy;
  final VoidCallback? onNext, onPrevious;

  @override
  Widget build(BuildContext context) {
    final active = controller.activeGroup(pile);
    final offer = controller.activeOffer(active);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(pile.name, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('${pile.quantity} carte · ${pile.groups.length} gruppi'),
      const SizedBox(height: 12),
      CheckoutStackPicker(
          groups: pile.groups,
          selected: active.key,
          onSelected: onOpenGroup,
          stackBuilder: (stack) => CheckoutBundleGesture(
              key: const ValueKey('checkout-bundle-gesture'),
              targetId: '${controller.cart.sessionVersion}:${offer.listing.id}',
              onRemove: controller.cart.canEdit
                  ? () => onRemoveCopy(offer.listing.id)
                  : null,
              onNext: onNext,
              onPrevious: onPrevious,
              child: stack)),
      TextButton.icon(
          onPressed: () => onOpenGroup(active.key),
          icon: const Icon(Icons.info_outline),
          label: const Text('Vedi offerte e venditori')),
    ]);
  }
}
