import 'package:flutter/widgets.dart';
import '../../../controller/wardrobe_controller.dart';

class WardrobeScope extends InheritedNotifier<WardrobeController> {
  const WardrobeScope(
      {super.key, required WardrobeController controller, required super.child})
      : super(notifier: controller);

  static WardrobeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WardrobeScope>()?.notifier;
}
