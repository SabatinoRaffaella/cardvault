import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../model/checkout_group.dart';
import '../../../style/checkout_style.dart';
import '../../shared/atomics/marketplace_thumbnail.dart';

/// Upright cover flow. Only the active group and its nearest neighbors build art.
class CheckoutCardStack extends StatelessWidget {
  const CheckoutCardStack(
      {super.key,
      required this.groups,
      required this.colors,
      required this.selected,
      required this.onSelected});
  final List<CheckoutGroup> groups;
  final List<Color> colors;
  final CheckoutGroupKey selected;
  final ValueChanged<CheckoutGroupKey> onSelected;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final found = groups.indexWhere((group) => group.key == selected);
    final current = found < 0 ? 0 : found;
    final scheme = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : CheckoutStyle.carouselDuration;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : 360.0;
      final cardWidth = math.min(CheckoutStyle.carouselMaxCardWidth,
          width * CheckoutStyle.carouselCardFraction);
      final cardHeight = cardWidth / CheckoutStyle.cardAspectRatio;
      final step = cardWidth * .55;
      return SizedBox(
          width: width,
          height: cardHeight + 72,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            // Paint distant faces first; the active card always stays in front.
            for (final offset in const [-2, 2, -1, 1, 0])
              if (current + offset >= 0 && current + offset < groups.length)
                AnimatedPositioned(
                    key: ValueKey(groups[current + offset].key),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: (width - cardWidth) / 2 + offset * step,
                    top: offset == 0 ? 20 : 34 + offset.abs() * 4.0,
                    width: cardWidth + 10,
                    height: cardHeight + 10,
                    child: AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        transformAlignment: Alignment.center,
                        transform: CheckoutStyle.uprightProjection(offset),
                        child: Stack(clipBehavior: Clip.none, children: [
                          for (var page = math.min(
                                      groups[current + offset].quantity, 4) -
                                  1;
                              page > 0;
                              page--)
                            Positioned(
                                left: page * 2.0,
                                top: page * 2.0,
                                width: cardWidth,
                                height: cardHeight,
                                child: IgnorePointer(
                                    child: DecoratedBox(
                                        decoration: CheckoutStyle.stackFace(
                                            scheme,
                                            colors[current + offset])))),
                          Positioned(
                              left: 0,
                              top: 0,
                              width: cardWidth,
                              height: cardHeight,
                              child: Semantics(
                                  button: true,
                                  selected: offset == 0,
                                  label:
                                      '${groups[current + offset].offers.first.card.name}, '
                                      '${groups[current + offset].key.condition}, '
                                      '${groups[current + offset].key.language}, '
                                      '${groups[current + offset].quantity} copie',
                                  child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => onSelected(
                                          groups[current + offset].key),
                                      child: AnimatedContainer(
                                          duration: duration,
                                          decoration: CheckoutStyle.stackFace(
                                              scheme, colors[current + offset],
                                              cover: true, active: offset == 0),
                                          padding: const EdgeInsets.all(4),
                                          child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: MarketplaceThumbnail(
                                                  imageUrl:
                                                      groups[current + offset]
                                                          .offers
                                                          .first
                                                          .card
                                                          .imageUrl,
                                                  width: cardWidth - 8,
                                                  height: cardHeight - 8)))))),
                        ]))),
          ]));
    });
  }
}
