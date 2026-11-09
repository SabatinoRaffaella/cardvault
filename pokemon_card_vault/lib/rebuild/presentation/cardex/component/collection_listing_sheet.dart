import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../model/cardex.dart';
import '../../../controller/collection_listing_controller.dart';
import '../../../model/collection_listing.dart';
import '../../../model/marketplace_home.dart';

class CollectionListingSheet extends StatefulWidget {
  const CollectionListingSheet(
      {super.key,
      required this.card,
      required this.collection,
      required this.controller,
      this.language,
      this.collectionChanges});
  final MarketplaceCardPreview card;
  final CardCollection Function() collection;
  final String? language;
  final Listenable? collectionChanges;
  final CollectionListingController controller;
  @override
  State<CollectionListingSheet> createState() => _CollectionListingSheetState();
}

class _CollectionListingSheetState extends State<CollectionListingSheet> {
  final _price = TextEditingController();
  final _form = GlobalKey<FormState>();
  CollectionListingTarget? _target;
  CollectionDisposition _desired = CollectionDisposition.collection;

  @override
  void initState() {
    super.initState();
    final targets = _targets;
    if (targets.isNotEmpty) _select(targets.first);
  }

  List<CollectionListingTarget> get _targets => widget.controller
      .targets(widget.collection(), widget.card.id, widget.language);

  void _select(CollectionListingTarget target) {
    _target = target;
    _desired = target.listed
        ? CollectionDisposition.listing
        : CollectionDisposition.collection;
    _price.text =
        target.item.card.pricePkn?.toStringAsFixed(2).replaceAll('.', ',') ??
            '';
  }

  double? get _amount =>
      double.tryParse(_price.text.trim().replaceAll(',', '.'));

  Future<void> _confirm() async {
    final target = _target;
    if (target == null) return;
    if (_desired == CollectionDisposition.listing &&
        !_form.currentState!.validate()) {
      return;
    }
    final success = await widget.controller.change(widget.collection(), target,
        _desired, _desired == CollectionDisposition.listing ? _amount : null);
    if (mounted && success) Navigator.of(context).pop(true);
  }

  Future<void> _verify() async {
    final success = await widget.controller.verifyPending();
    if (mounted && success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        if (widget.collectionChanges != null) widget.collectionChanges!
      ]),
      builder: (context, _) {
        final actions = widget.controller;
        final targets = _targets;
        final target = _target;
        final available =
            target != null && targets.any((row) => row.key == target.key);
        final changed = target != null &&
            (target.listed
                ? _desired == CollectionDisposition.collection ||
                    _amount != target.item.card.pricePkn
                : _desired == CollectionDisposition.listing);
        return PopScope(
            canPop: !actions.busy,
            child: SafeArea(
                child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 12, 20,
                        20 + MediaQuery.viewInsetsOf(context).bottom),
                    child: Form(
                        key: _form,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(widget.card.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge)),
                                IconButton(
                                    tooltip: 'Chiudi',
                                    onPressed: actions.busy
                                        ? null
                                        : () =>
                                            Navigator.of(context).pop(false),
                                    icon: const Icon(Icons.close))
                              ]),
                              Text(widget.card.expansion),
                              const SizedBox(height: 16),
                              if (actions.uncertain) ...[
                                const Text(
                                    'Una modifica inviata deve ancora essere verificata. Non verrà inviata di nuovo.'),
                                const SizedBox(height: 12),
                                FilledButton(
                                    onPressed: actions.busy ? null : _verify,
                                    child: const Text('Verifica esito')),
                              ] else if (available) ...[
                                if (targets.length > 1)
                                  DropdownButtonFormField<String>(
                                      initialValue: target.key,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'Copia / variante'),
                                      items: [
                                        for (final row in targets)
                                          DropdownMenuItem(
                                              value: row.key,
                                              child: Text(
                                                  '${row.item.language} · ${row.item.attributes['condition'] ?? 'NM'} · '
                                                  '${row.item.quantity} copie · ${row.listed ? 'Listing' : 'Collezione'}',
                                                  overflow:
                                                      TextOverflow.ellipsis))
                                      ],
                                      onChanged: actions.busy
                                          ? null
                                          : (key) => setState(() => _select(
                                              targets.firstWhere(
                                                  (row) => row.key == key))))
                                else
                                  Text(
                                      '${target.item.language} · ${target.item.attributes['condition'] ?? 'NM'} · '
                                      '${target.item.quantity} ${target.item.quantity == 1 ? 'copia' : 'copie'}'),
                                const SizedBox(height: 12),
                                Wrap(spacing: 8, children: [
                                  for (final value
                                      in CollectionDisposition.values)
                                    ChoiceChip(
                                        label: Text(value ==
                                                CollectionDisposition.collection
                                            ? 'Collezione'
                                            : 'Listing'),
                                        selected: _desired == value,
                                        onSelected: actions.busy
                                            ? null
                                            : (_) => setState(
                                                () => _desired = value))
                                ]),
                                const SizedBox(height: 16),
                                if (_desired ==
                                    CollectionDisposition.listing) ...[
                                  TextFormField(
                                      controller: _price,
                                      enabled: !actions.busy,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9,.]'))
                                      ],
                                      decoration: const InputDecoration(
                                          labelText: 'Prezzo per copia',
                                          suffixText: 'PKN'),
                                      onChanged: (_) => setState(() {}),
                                      validator: (value) => !RegExp(
                                                      r'^\d+(?:[.,]\d{1,2})?$')
                                                  .hasMatch(
                                                      (value ?? '').trim()) ||
                                              _amount == null ||
                                              !_amount!.isFinite ||
                                              _amount! <= 0
                                          ? 'Inserisci un prezzo maggiore di zero, con massimo due decimali.'
                                          : null),
                                  const SizedBox(height: 12),
                                  Text(
                                      'La conferma mette in vendita ${target.item.quantity} '
                                      '${target.item.quantity == 1 ? 'copia' : 'copie'} di questa variante su Pokoin.'),
                                ] else
                                  const Text(
                                      'La conferma toglie questa variante dalla vendita su Pokoin. La carta resta posseduta.'),
                                const SizedBox(height: 16),
                                FilledButton(
                                    onPressed: actions.busy ||
                                            !actions.signedIn ||
                                            !changed
                                        ? null
                                        : _confirm,
                                    child: Text(_desired ==
                                            CollectionDisposition.listing
                                        ? 'Conferma Listing'
                                        : 'Conferma Collezione')),
                              ] else
                                const Text(
                                    'La copia non è disponibile per il cambio. Aggiorna la collezione.'),
                              if (actions.busy)
                                const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: LinearProgressIndicator()),
                              if (actions.error != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Semantics(
                                        liveRegion: true,
                                        child: Text(actions.error!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)))),
                            ])))));
      });

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }
}
