import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../model/checkout_group.dart';
import '../../../style/checkout_style.dart';
import '../../shared/atomics/marketplace_thumbnail.dart';

/// A bounded 2.5D stack: one cached artwork per visible group, paper-only copies.
class CheckoutCardStack extends StatelessWidget {
  const CheckoutCardStack(
      {super.key,
      required this.groups,
      required this.colors,
      required this.onSelected});
  final List<CheckoutGroup> groups;
  final List<Color> colors;
  final ValueChanged<CheckoutGroupKey> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = 180 + (groups.length - 1) * CheckoutStyle.stackGroupOffset;
    return SizedBox(
        height: height,
        child: Center(
            child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: CheckoutStyle.stackWidth,
            height: height,
            child: Stack(clipBehavior: Clip.none, children: [
              for (var i = groups.length - 1; i >= 0; i--)
                for (var page = math.min(groups[i].quantity, 5) - 1;
                    page >= 0;
                    page--)
                  Positioned(
                      left: 10,
                      top: 80 + i * CheckoutStyle.stackGroupOffset + page * 2.0,
                      child: Transform(
                        alignment: Alignment.topLeft,
                        transform: CheckoutStyle.stackProjection(),
                        child: GestureDetector(
                          onTap: () => onSelected(groups[i].key),
                          child: Container(
                            width: CheckoutStyle.stackFaceWidth,
                            height: CheckoutStyle.stackFaceHeight,
                            decoration: CheckoutStyle.stackFace(
                                scheme, colors[i],
                                cover: page == 0),
                            padding: EdgeInsets.all(page == 0 ? 4 : 0),
                            child: page == 0
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: MarketplaceThumbnail(
                                        imageUrl: groups[i]
                                            .offers
                                            .first
                                            .card
                                            .imageUrl,
                                        width: CheckoutStyle.stackFaceWidth - 8,
                                        height:
                                            CheckoutStyle.stackFaceHeight - 8))
                                : null,
                          ),
                        ),
                      )),
            ]),
          ),
        )));
  }
}
