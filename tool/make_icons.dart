// Builds every icon variant from the one source image.
//
//   dart run tool/make_icons.dart
//   dart run flutter_launcher_icons
//
// Source: assets/brand/app_icon.png (square, rounded corners transparent).
import 'dart:io';

import 'package:image/image.dart';

const src = 'assets/brand/app_icon.png';
const out = 'assets/brand';

/// Mint for the corners the source leaves transparent.
final mint = ColorRgba8(187, 239, 203, 255);

void main() {
  final icon = decodePng(File(src).readAsBytesSync())!;
  final size = icon.width;

  // Square with the transparent corners filled: iOS rejects transparency
  // and rounds the corners itself.
  final square = Image(width: size, height: size, numChannels: 4)..clear(mint);
  compositeImage(square, icon);
  _save(square, 'app_icon_square.png');

  // Android adaptive icon and web "maskable" icon: launchers and browsers
  // crop these to circles, squircles and so on, so they take the wallet
  // alone (lifted off its tile), centred in the safe zone, on flat mint.
  final glyph = _liftWallet(icon);
  _save(glyph, 'app_icon_glyph.png');
  final bg = _backgroundColor(icon);
  stdout.writeln('adaptive background: #${_hex(bg)}');

  final fg = Image(width: size, height: size, numChannels: 4);
  final scaled = (size * 0.69).round();
  final small = copyResize(glyph, width: scaled, height: scaled, interpolation: Interpolation.cubic);
  final at = (size - scaled) ~/ 2;
  compositeImage(fg, _shadow(small, ColorRgba8(30, 110, 70, 255)), dstX: at, dstY: at + (size * 0.02).round());
  compositeImage(fg, small, dstX: at, dstY: at);
  _save(fg, 'app_icon_adaptive_fg.png');

  final safe = Image(width: size, height: size, numChannels: 4)..clear(bg);
  compositeImage(safe, fg);
  _save(safe, 'app_icon_maskable.png');

  // macOS: Apple's grid leaves about 10% clear around the rounded square.
  final mac = Image(width: 1024, height: 1024, numChannels: 4);
  compositeImage(mac, copyResize(icon, width: 824, height: 824, interpolation: Interpolation.cubic),
      dstX: 100, dstY: 100);
  _save(mac, 'app_icon_macos.png');

  // Web files that flutter_launcher_icons does not cover.
  _write(copyResize(icon, width: 32, height: 32, interpolation: Interpolation.average), 'web/favicon.png');
  _write(copyResize(square, width: 180, height: 180, interpolation: Interpolation.cubic), 'web/icons/apple-touch-icon.png');
  for (final s in [192, 512]) {
    _write(copyResize(safe, width: s, height: s, interpolation: Interpolation.cubic), 'web/icons/Icon-maskable-$s.png');
  }
}

/// How much a pixel looks like the mint tile (1) rather than the wallet
/// or coins (0). Mint is the only colour where green clearly leads both
/// red and blue; the blue leather and gold coins never do.
double _mintness(Pixel p) {
  final lead = [p.g - p.r, p.g - p.b].reduce((a, b) => a < b ? a : b).toDouble();
  final t = ((lead - 4) / 16).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The wallet and coins on a transparent background.
Image _liftWallet(Image tile) {
  final out = Image(width: tile.width, height: tile.height, numChannels: 4);
  for (final p in tile) {
    if (p.a == 0) continue;
    final keep = 1 - _mintness(p);
    if (keep <= 0) continue;
    out.setPixelRgba(p.x, p.y, p.r, p.g, p.b, p.a * keep);
  }
  return out;
}

/// The tile's typical mint, from the pixels that are clearly tile.
Color _backgroundColor(Image tile) {
  var r = 0, g = 0, b = 0, n = 0;
  for (final p in tile) {
    if (p.a < 255 || _mintness(p) < 1) continue;
    r += p.r.toInt();
    g += p.g.toInt();
    b += p.b.toInt();
    n++;
  }
  return ColorRgba8(r ~/ n, g ~/ n, b ~/ n, 255);
}

/// A soft shadow in [color] shaped like [im].
Image _shadow(Image im, Color color) {
  final s = Image(width: im.width, height: im.height, numChannels: 4);
  for (final p in im) {
    s.setPixelRgba(p.x, p.y, color.r, color.g, color.b, p.a * 0.28);
  }
  return gaussianBlur(s, radius: (im.width * 0.03).round());
}

String _hex(Color c) =>
    [c.r, c.g, c.b].map((v) => v.toInt().toRadixString(16).padLeft(2, '0')).join().toUpperCase();

void _save(Image image, String name) => _write(image, '$out/$name');

void _write(Image image, String path) {
  File(path).writeAsBytesSync(encodePng(image));
  stdout.writeln('wrote $path (${image.width}x${image.height})');
}
