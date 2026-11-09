import 'package:flutter/material.dart';
import '../../../model/app_appearance.dart';
import '../component/app_appearance_scope.dart';
import '../component/wardrobe_scope.dart';
import 'wardrobe_avatar.dart';

class PokoinBrandMark extends StatelessWidget {
  const PokoinBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppAppearanceScope.maybeOf(context)?.appearance ==
        AppAppearance.dungeonCrawler) {
      final wardrobe = WardrobeScope.maybeOf(context);
      if (wardrobe != null) {
        if (!wardrobe.ready) return const SizedBox.square(dimension: 30);
        return WardrobeAvatar(selection: wardrobe.selection);
      }
    }
    return Image.asset('assets/brand/pokoin-96.png',
        width: 30, height: 30, semanticLabel: 'pokoin');
  }
}
