/// Original trimmed PNGs, positioned on one 80 x 80 logical pixel canvas.
/// Keep alignment here: no image processing or duplicate image files.
class WardrobeSprite {
  const WardrobeSprite(this.path, this.left, this.top, this.width, this.height);
  final String path;
  final double left, top, width, height;
}

abstract final class WardrobeStyle {
  static const canvasSize = 80.0;
  static const background = WardrobeSprite(
      'assets/icons/wardrobe/backgrounds/silver.png', 8, 8, 64, 64);
  static const base =
      WardrobeSprite('assets/icons/wardrobe/base/poko.png', 16, 22, 47, 43);
  static const accessories = {
    'batty': WardrobeSprite(
        'assets/icons/wardrobe/headgear/Batty.png', 15, 16, 44, 20),
    'skellyyyy': WardrobeSprite(
        'assets/icons/wardrobe/headgear/Skellyyyy.png', 19, 11, 41, 26),
    'lumachina': WardrobeSprite(
        'assets/icons/wardrobe/hand/Lumachina.png', 47, 38, 31.5, 22.4),
    'boots': WardrobeSprite(
        'assets/icons/wardrobe/foot/Fatati Boots.png', 19, 57, 40, 12),
    'carpet': WardrobeSprite(
        'assets/icons/wardrobe/foot/Magico Carpet.png', 11, 47, 56, 27),
  };
}
