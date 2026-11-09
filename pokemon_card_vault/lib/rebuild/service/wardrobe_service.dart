import 'dart:convert';
import '../constants/wardrobe_constants.dart';
import '../model/wardrobe.dart';
import '../provider/wardrobe_provider.dart';

class WardrobeService {
  WardrobeService({WardrobeProvider? provider})
      : _provider = provider ?? WardrobeProvider();
  final WardrobeProvider _provider;

  WardrobeSelection normalize(WardrobeSelection value) {
    var result = const WardrobeSelection();
    for (final slot in WardrobeSlot.values) {
      final id = value.forSlot(slot);
      if (wardrobeAccessories
          .any((item) => item.slot == slot && item.id == id)) {
        result = result.withAccessory(slot, id);
      }
    }
    return result;
  }

  Future<WardrobeSelection> load() async {
    final raw = await _provider.read();
    if (raw == null) return const WardrobeSelection();
    final data = jsonDecode(raw);
    if (data is! Map || data['version'] != 1) {
      throw const FormatException('Invalid wardrobe preference');
    }
    return normalize(WardrobeSelection(
      head: data['head'] is String ? data['head'] as String : null,
      hand: data['hand'] is String ? data['hand'] as String : null,
      feet: data['feet'] is String ? data['feet'] as String : null,
    ));
  }

  Future<void> save(WardrobeSelection value) =>
      _provider.write(jsonEncode(normalize(value).toJson()));
}
