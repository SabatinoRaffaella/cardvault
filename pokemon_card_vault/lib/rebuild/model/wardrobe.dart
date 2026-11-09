enum WardrobeSlot { head, hand, feet }

class WardrobeAccessory {
  const WardrobeAccessory(this.id, this.label, this.slot);
  final String id, label;
  final WardrobeSlot slot;
}

/// Stable accessory IDs only: stored preferences never supply image paths.
class WardrobeSelection {
  const WardrobeSelection({this.head, this.hand, this.feet});
  final String? head, hand, feet;

  String? forSlot(WardrobeSlot slot) => switch (slot) {
        WardrobeSlot.head => head,
        WardrobeSlot.hand => hand,
        WardrobeSlot.feet => feet,
      };

  WardrobeSelection withAccessory(WardrobeSlot slot, String? id) =>
      WardrobeSelection(
        head: slot == WardrobeSlot.head ? id : head,
        hand: slot == WardrobeSlot.hand ? id : hand,
        feet: slot == WardrobeSlot.feet ? id : feet,
      );

  Map<String, dynamic> toJson() =>
      {'version': 1, 'head': head, 'hand': hand, 'feet': feet};

  @override
  bool operator ==(Object other) =>
      other is WardrobeSelection &&
      head == other.head &&
      hand == other.hand &&
      feet == other.feet;
  @override
  int get hashCode => Object.hash(head, hand, feet);
}
