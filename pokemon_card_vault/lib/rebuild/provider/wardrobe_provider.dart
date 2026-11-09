import 'package:shared_preferences/shared_preferences.dart';

/// Device-local cosmetics only, shared with guest browsing; no account data.
class WardrobeProvider {
  static const key = 'rebuild.wardrobe.v1';
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Wardrobe preference was not saved');
    }
  }
}
