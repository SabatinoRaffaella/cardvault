import 'package:flutter/material.dart';
import '../../shared/component/wardrobe_scope.dart';
import '../wardrobe_screen.dart';

class WardrobeButton extends StatelessWidget {
  const WardrobeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = WardrobeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Guardaroba di Poko',
      icon: Icon(Icons.door_sliding_outlined,
          color: Theme.of(context).colorScheme.primary),
      onPressed: !controller.ready
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => WardrobeScreen(controller: controller))),
    );
  }
}
