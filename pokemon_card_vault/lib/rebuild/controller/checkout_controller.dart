import 'package:flutter/foundation.dart';
import '../model/cart_item.dart';
import '../model/checkout_group.dart';
import '../service/checkout_service.dart';
import 'cart_controller.dart';

/// Owns temporary checkout selection; the shared cart owns persistence/session.
class CheckoutController extends ChangeNotifier {
  CheckoutController(this.cart) {
    _synchronize();
    cart.addListener(_changed);
  }
  final CartController cart;
  List<CheckoutGroup> _groups = const [];
  List<CheckoutPile> _piles = const [];
  Map<String, ListingCartItem> _items = {};
  final _selected = <String, int>{};
  final _active = <CheckoutGroupKey, String>{};
  final _activeGroups = <String, CheckoutGroupKey>{};
  ({
    ListingCartItem item,
    int selectedBefore,
    int selectedAfter,
    int session
  })? _removal;
  bool _disposed = false;

  bool get canUndo =>
      !_disposed &&
      _removal != null &&
      _removal!.session == cart.sessionVersion &&
      cart.canEdit;
  ListingCartItem? get removedItem => canUndo ? _removal?.item : null;
  CheckoutGroup activeGroup(CheckoutPile pile) =>
      pile.groups.firstWhere((group) => group.key == _activeGroups[pile.id],
          orElse: () => pile.groups.first);
  void selectPileGroup(CheckoutPile pile, CheckoutGroupKey key) {
    if (_disposed || !pile.groups.any((group) => group.key == key)) return;
    _activeGroups[pile.id] = key;
    notifyListeners();
  }

  List<CheckoutGroup> get groups => _groups;
  List<CheckoutPile> get piles => _piles;
  int selectedQuantity(String id) => _selected[id] ?? 0;
  int get selectedCount => _selected.values.fold(0, (sum, n) => sum + n);
  double get selectedTotalPkn => _items.values.fold(
      0,
      (sum, item) =>
          sum + item.listing.pricePkn * selectedQuantity(item.listing.id));
  List<ListingCartItem> get selectedItems => List.unmodifiable(_items.values
      .where((item) => selectedQuantity(item.listing.id) > 0)
      .map((item) => item.withQuantity(selectedQuantity(item.listing.id))));
  int selectedIn(CheckoutGroup group) => group.offers
      .fold(0, (sum, item) => sum + selectedQuantity(item.listing.id));
  bool? selectionFor(CheckoutGroup group) {
    final count = selectedIn(group);
    return count == 0
        ? false
        : count == group.quantity
            ? true
            : null;
  }

  ListingCartItem activeOffer(CheckoutGroup group) =>
      group.offers.firstWhere((item) => item.listing.id == _active[group.key],
          orElse: () => group.offers.first);

  void selectOffer(CheckoutGroup group, String id) {
    if (!group.offers.any((item) => item.listing.id == id) ||
        !_items.containsKey(id) ||
        _active[group.key] == id) {
      return;
    }
    _active[group.key] = id;
    notifyListeners();
  }

  void selectGroup(CheckoutGroup group, bool selected) {
    if (!cart.canEdit) return;
    for (final item in group.offers) {
      final current = _items[item.listing.id];
      if (current != null) {
        _selected[item.listing.id] = selected ? current.quantity : 0;
      }
    }
    notifyListeners();
  }

  void selectAll(bool selected) {
    if (!cart.canEdit) return;
    for (final item in _items.values) {
      _selected[item.listing.id] = selected ? item.quantity : 0;
    }
    notifyListeners();
  }

  void setSelectedQuantity(String id, int quantity) {
    final item = _items[id];
    if (!cart.canEdit || item == null) return;
    final next = quantity.clamp(0, item.quantity);
    if (_selected[id] == next) return;
    _selected[id] = next;
    notifyListeners();
  }

  bool removeCopy(String id) {
    final item = _items[id];
    if (_disposed || !cart.canEdit || item == null) return false;
    final before = selectedQuantity(id);
    final session = cart.sessionVersion;
    cart.decreaseListing(id);
    if (_disposed || session != cart.sessionVersion) return false;
    if (cart.listingItems.any(
        (row) => row.listing.id == id && row.quantity != item.quantity - 1)) {
      return false;
    }
    _removal = (
      item: item,
      selectedBefore: before,
      selectedAfter: selectedQuantity(id),
      session: session
    );
    notifyListeners();
    return true;
  }

  bool undoRemoval() {
    if (!canUndo) return false;
    final removal = _removal!;
    final selected = selectedQuantity(removal.item.listing.id) +
        removal.selectedBefore -
        removal.selectedAfter;
    _removal = null;
    final restored = cart.restoreListingCopy(removal.item);
    if (restored) {
      final item = _items[removal.item.listing.id];
      if (item != null) {
        _selected[item.listing.id] = selected.clamp(0, item.quantity);
        for (final pile in _piles) {
          for (final group in pile.groups) {
            if (group.offers.any((row) => row.listing.id == item.listing.id)) {
              _active[group.key] = item.listing.id;
              _activeGroups[pile.id] = group.key;
            }
          }
        }
      }
    }
    notifyListeners();
    return restored;
  }

  void removeOffer(String id) {
    if (_disposed || !cart.canEdit) return;
    _removal = null;
    cart.removeListing(id);
  }

  void _synchronize() {
    final previous = _items;
    _items = {for (final item in cart.listingItems) item.listing.id: item};
    _selected.removeWhere((id, _) => !_items.containsKey(id));
    for (final item in _items.values) {
      final id = item.listing.id;
      final selected = _selected[id];
      _selected[id] = selected == null || selected == previous[id]?.quantity
          ? item.quantity
          : selected.clamp(0, item.quantity);
    }
    _groups = CheckoutService.group(_items.values);
    _piles = CheckoutService.piles(_groups);
    _activeGroups.removeWhere((id, key) => !_piles.any((pile) =>
        pile.id == id && pile.groups.any((group) => group.key == key)));
    _active.removeWhere((key, _) => !_groups.any((group) => group.key == key));
    for (final group in _groups) {
      if (!group.offers.any((item) => item.listing.id == _active[group.key])) {
        _active[group.key] = group.offers.first.listing.id;
      }
    }
  }

  void _changed() {
    if (cart.isLoading ||
        (_removal != null && _removal!.session != cart.sessionVersion)) {
      _removal = null;
    }
    _synchronize();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _removal = null;
    cart.removeListener(_changed);
    super.dispose();
  }
}
