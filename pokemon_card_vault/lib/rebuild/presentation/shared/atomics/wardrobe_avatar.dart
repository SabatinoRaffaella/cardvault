import 'package:flutter/material.dart';
import '../../../model/wardrobe.dart';
import '../../../style/dungeon_crawler/wardrobe_style.dart';

/// Local transparent layers only. All thumbnails and the toolbar reuse this.
class WardrobeAvatar extends StatelessWidget {
  const WardrobeAvatar({super.key, required this.selection, this.size = 30});
  final WardrobeSelection selection;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pieces = [
      WardrobeStyle.background,
      if (selection.feet == 'carpet') WardrobeStyle.accessories['carpet']!,
      WardrobeStyle.base,
      if (WardrobeStyle.accessories[selection.head] case final sprite?) sprite,
      if (selection.feet == 'boots') WardrobeStyle.accessories['boots']!,
      if (WardrobeStyle.accessories[selection.hand] case final sprite?) sprite,
    ];
    return Semantics(
      label: 'Poko personalizzato',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(
          child: SizedBox.square(
            dimension: WardrobeStyle.canvasSize,
            child: Stack(children: [
              for (final piece in pieces)
                Positioned(
                  key: ValueKey(piece.path),
                  left: piece.left,
                  top: piece.top,
                  width: piece.width,
                  height: piece.height,
                  child: Image.asset(piece.path,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => piece == WardrobeStyle.base
                          ? Image.asset('assets/brand/pokoin-96.png',
                              excludeFromSemantics: true)
                          : const SizedBox.shrink()),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
