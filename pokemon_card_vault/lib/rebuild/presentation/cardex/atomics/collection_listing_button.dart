import 'package:flutter/material.dart';
import '../../../controller/cardex_controller.dart';
import '../../../controller/collection_listing_controller.dart';
import '../../../model/marketplace_home.dart';
import '../component/collection_listing_sheet.dart';

class CollectionListingButton extends StatelessWidget {
  const CollectionListingButton(
      {super.key, required this.card, required this.cardex, this.controller});
  final MarketplaceCardPreview card;
  final CardexController cardex;
  final CollectionListingController? controller;

  static double height(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(12) * 1.3 + 18;

  Future<void> _open(BuildContext context) async {
    final actions = controller!;
    actions.start();
    actions.clearFeedback();
    final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => CollectionListingSheet(
            card: card,
            collection: () => cardex.collection,
            collectionChanges: cardex,
            language: cardex.ownershipFor(card.id).selectedLanguage,
            controller: actions));
    if (result == true) {
      cardex.retryCollection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Cambio confermato dal server. Collezione aggiornata.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable:
          Listenable.merge([cardex, if (controller != null) controller!]),
      builder: (context, _) {
        final ownership = cardex.ownershipFor(card.id);
        final targets = controller?.targets(
                cardex.collection, card.id, ownership.selectedLanguage) ??
            const [];
        final label = !ownership.known
            ? 'Sincronizzazione…'
            : !ownership.hasConfirmedCopies
                ? 'Catalogo'
                : targets.isNotEmpty && targets.every((row) => row.listed)
                    ? 'Listing'
                    : 'Collezione';
        final enabled =
            ownership.known && targets.isNotEmpty && controller?.busy == false;
        return SizedBox(
            height: height(context),
            width: double.infinity,
            child: Tooltip(
                message:
                    'Stato di vendita della copia. Le eventuali scansioni del catalogo non cambiano il possesso.',
                child: OutlinedButton(
                    onPressed: enabled ? () => _open(context) : null,
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                              child: Text(label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          if (enabled) const Icon(Icons.expand_more, size: 16),
                        ]))));
      });
}
