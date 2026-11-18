import 'package:flutter/material.dart';

class OfferSelector extends StatelessWidget {
  const OfferSelector(
      {super.key,
      required this.index,
      required this.count,
      required this.onPrevious,
      required this.onNext});
  final int index, count;
  final VoidCallback? onPrevious, onNext;
  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(
            tooltip: 'Offerta precedente',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Semantics(
                liveRegion: true,
                child: Text('Offerta ${index + 1} di $count',
                    textAlign: TextAlign.center))),
        IconButton(
            tooltip: 'Offerta successiva',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right)),
      ]);
}
