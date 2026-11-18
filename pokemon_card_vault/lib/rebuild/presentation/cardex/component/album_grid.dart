import 'package:flutter/material.dart';
import '../../../model/cardex.dart';
import '../../../model/card_ownership.dart';
import '../../../model/marketplace_home.dart';
import '../../../style/cardex_style.dart';
import '../atomics/album_card.dart';
import '../atomics/album_card_caption.dart';
import '../../shared/component/card_ownership_edge_controls.dart';

/// Due colonne come le pagine di un album; costruisce solo le tasche visibili.
class AlbumGrid extends StatelessWidget {
  const AlbumGrid(
      {super.key,
      required this.cards,
      required this.collection,
      this.ownershipFor,
      this.onLanguageSelected,
      this.priceLabelFor,
      required this.onOpen});
  final List<MarketplaceCardPreview> cards;
  final CardCollection collection;
  final CardOwnership Function(String)? ownershipFor;
  final void Function(String, String)? onLanguageSelected;
  final ValueChanged<MarketplaceCardPreview> onOpen;
  final String Function(MarketplaceCardPreview)? priceLabelFor;

  @override
  Widget build(BuildContext context) =>
      SliverLayoutBuilder(builder: (context, constraints) {
        final columns = constraints.crossAxisExtent >= 700 ? 4 : 2;
        final width =
            (constraints.crossAxisExtent - (columns - 1) * 12) / columns;
        final indices = {for (var i = 0; i < cards.length; i++) cards[i].id: i};
        return SliverGrid.builder(
            itemCount: cards.length,
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? indices[key.value] : null,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: (width - 6) / CardexStyle.cardAspectRatio +
                    6 +
                    CardOwnershipEdgeControls.railHeight(context) +
                    AlbumCardCaption.footerHeight(context,
                        showPrice: priceLabelFor != null)),
            itemBuilder: (context, index) {
              final card = cards[index];
              return DecoratedBox(
                  key: ValueKey(card.id),
                  decoration: const BoxDecoration(color: CardexStyle.seam),
                  child: AlbumCard(
                      card: card,
                      viewportPosition: Scrollable.maybeOf(context)?.position,
                      previewWhileLoading: true,
                      priceLabel: priceLabelFor?.call(card),
                      quantity: collection.quantityFor(card.id),
                      ownership: ownershipFor?.call(card.id),
                      onLanguageSelected: onLanguageSelected == null
                          ? null
                          : (language) =>
                              onLanguageSelected!(card.id, language),
                      ownershipKnown:
                          collection.status == CollectionStatus.ready,
                      onOpen: () => onOpen(card)));
            });
      });
}
