import 'package:flutter/material.dart';
import 'dart:convert';
import '../model/checkout_group.dart';

abstract final class CheckoutStyle {
  /// The warm palette used by the approved bundle preview, scoped to Checkout.
  static ThemeData theme(ThemeData base) {
    final dark = base.brightness == Brightness.dark;
    final background = dark ? const Color(0xff241b15) : const Color(0xfff5eddf);
    final surface = dark ? const Color(0xff39291f) : const Color(0xfffff9ef);
    final text = dark ? const Color(0xfff4ead8) : const Color(0xff372c22);
    final subtle = dark ? const Color(0xffcdbda8) : const Color(0xff6e5a44);
    final line = dark ? const Color(0xff72593e) : const Color(0xffd4bfa2);
    final accent = dark ? const Color(0xffd5e87c) : const Color(0xff546423);
    final onAccent = dark ? const Color(0xff25300e) : Colors.white;
    final colors = base.colorScheme.copyWith(
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: subtle,
        surfaceContainerHighest: background,
        outline: line,
        outlineVariant: line,
        error: dark ? const Color(0xffffaca0) : const Color(0xffa22e24));
    return base.copyWith(
        colorScheme: colors,
        scaffoldBackgroundColor: background,
        textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
        iconTheme: IconThemeData(color: text),
        appBarTheme: base.appBarTheme.copyWith(
            backgroundColor:
                dark ? const Color(0xff4c2b12) : const Color(0xffead6b8),
            foregroundColor: text),
        checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? accent : null),
            checkColor: WidgetStatePropertyAll(onAccent)));
  }

  static const pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
  static const panelPadding = EdgeInsets.all(16);
  static const radius = BorderRadius.all(Radius.circular(20));
  static const cardAspectRatio = 63 / 88;
  static const carouselCardFraction = .58;
  static const carouselMaxCardWidth = 220.0;
  static const carouselDuration = Duration(milliseconds: 220);

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

  /// Upright center card, with smaller neighboring faces turned toward it.
  static Matrix4 uprightProjection(int offset) {
    final scale = offset == 0
        ? 1.0
        : offset.abs() == 1
            ? .86
            : .74;
    return Matrix4.identity()
      ..setEntry(3, 2, .0012)
      ..rotateY(offset.sign * -.24)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
  }

  static BoxDecoration stackFace(ColorScheme colors, Color accent,
          {bool cover = false, bool active = false}) =>
      BoxDecoration(
          color:
              Color.lerp(colors.surfaceContainerHighest, colors.onSurface, .12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: accent,
              width: active
                  ? 3
                  : cover
                      ? 2
                      : 1),
          boxShadow: cover
              ? [
                  BoxShadow(
                      color: active
                          ? accent.withValues(alpha: .32)
                          : colors.shadow.withValues(alpha: .22),
                      blurRadius: active ? 18 : 8,
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
