import 'package:flutter/material.dart';
import 'dart:convert';
import '../model/checkout_group.dart';

abstract final class CheckoutStyle {
  static const pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
  static const panelPadding = EdgeInsets.all(16);
  static const radius = BorderRadius.all(Radius.circular(20));
  static const stackWidth = 300.0;
  static const stackFaceWidth = 150.0;
  static const stackFaceHeight = 210.0;
  static const stackGroupOffset = 42.0;

  /// Seeded by immutable identity, so colors survive sorting/removal/reopening.
  static Color stackAccent(ColorScheme colors, CheckoutGroupKey key) {
    final seed =
        jsonEncode([key.cardId, key.condition, key.language, key.variant]);
    var hash = 17;
    for (final rune in seed.runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    final hue = (hash * 137.507764) % 360;
    return HSLColor.fromAHSL(
            1, hue, .76, colors.brightness == Brightness.dark ? .68 : .38)
        .toColor();
  }

  /// Projects the card plane to a diamond while keeping its artwork intact.
  static Matrix4 stackProjection() => Matrix4.identity()
    ..setEntry(0, 0, .94)
    ..setEntry(0, 1, .65)
    ..setEntry(1, 0, -.52)
    ..setEntry(1, 1, .36);

  static BoxDecoration stackFace(ColorScheme colors, Color accent,
          {bool cover = false}) =>
      BoxDecoration(
          color:
              Color.lerp(colors.surfaceContainerHighest, colors.onSurface, .12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent, width: cover ? 3 : 1),
          boxShadow: cover
              ? [
                  BoxShadow(
                      color: colors.shadow.withValues(alpha: .22),
                      blurRadius: 8,
                      offset: const Offset(0, 5))
                ]
              : null);
  static BoxDecoration panel(ColorScheme colors,
          {required bool selected, Color? accent}) =>
      BoxDecoration(
          color: colors.surface,
          borderRadius: radius,
          border: Border.all(
              color:
                  selected ? accent ?? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1));
}
