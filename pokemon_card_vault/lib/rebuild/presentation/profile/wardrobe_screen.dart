import 'package:flutter/material.dart';
import '../../constants/wardrobe_constants.dart';
import '../../controller/wardrobe_controller.dart';
import '../../model/app_appearance.dart';
import '../../model/wardrobe.dart';
import '../shared/atomics/wardrobe_avatar.dart';
import '../shared/component/app_appearance_scope.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.controller});
  final WardrobeController controller;
  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  late WardrobeSelection _draft;
  WardrobeSlot _slot = WardrobeSlot.head;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.selection;
  }

  Future<void> _save() async {
    final saved = await widget.controller.save(_draft);
    if (mounted && saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final dungeon = AppAppearanceScope.maybeOf(context)?.appearance ==
              AppAppearance.dungeonCrawler;
          return PopScope(
            canPop: !controller.saving,
            child: Scaffold(
              appBar: AppBar(title: const Text('Guardaroba di Poko')),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    WardrobeAvatar(selection: _draft, size: 160),
                    const SizedBox(height: 12),
                    Text(
                        dungeon
                            ? 'Il tuo Poko nella barra di Dungeon Crawler.'
                            : 'Anteprima Dungeon Crawler. Attiva il tema dalla tavolozza per usarla nella barra.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final slot in WardrobeSlot.values)
                        ChoiceChip(
                          label: Text(wardrobeSlotLabels[slot]!),
                          selected: _slot == slot,
                          onSelected: controller.saving
                              ? null
                              : (_) => setState(() => _slot = slot),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 480 ? 3 : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 8) / columns;
                      return Wrap(spacing: 8, runSpacing: 8, children: [
                        _choice(null, 'Niente', width),
                        for (final item in wardrobeAccessories
                            .where((item) => item.slot == _slot))
                          _choice(item.id, item.label, width),
                      ]);
                    }),
                    const SizedBox(height: 16),
                    if (controller.feedback != null)
                      Semantics(
                          liveRegion: true, child: Text(controller.feedback!)),
                    const SizedBox(height: 8),
                    const Text('Preferenza salvata solo su questo dispositivo.',
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    TextButton(
                        onPressed: controller.saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Annulla')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: FilledButton.icon(
                      onPressed: controller.saving ? null : _save,
                      icon: controller.saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_rounded),
                      label: Text(
                          controller.saving ? 'Salvataggio…' : 'Salva look'),
                    )),
                  ]),
                ),
              ),
            ),
          );
        },
      );

  Widget _choice(String? id, String label, double width) {
    final selected = _draft.forSlot(_slot) == id;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Semantics(
        selected: selected,
        child: OutlinedButton(
          onPressed: widget.controller.saving
              ? null
              : () => setState(() {
                    _draft = _draft.withAccessory(_slot, id);
                  }),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(12),
            backgroundColor: selected ? colors.primaryContainer : null,
            foregroundColor: selected ? colors.onPrimaryContainer : null,
            side: BorderSide(color: selected ? colors.primary : colors.outline),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ExcludeSemantics(
                child: WardrobeAvatar(
                    selection: _draft.withAccessory(_slot, id), size: 72)),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Icon(selected ? Icons.check_circle_outline : Icons.circle_outlined,
                size: 18),
          ]),
        ),
      ),
    );
  }
}
