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

  // Android 12+ launch screen: the small icon and the empty progress bar,
  // placed exactly where the app's startup screen (lib/boot.dart) draws
  // them, so the system's launch screen and the app's look like one screen
  // and the bar simply starts to fill. Android draws this image over a
  // 288 dp square, centred and cropped to a rounded shape, so 1 dp = 4 px
  // here (1152 px). It is painted on the launch screen's own colour, so the
  // crop is invisible and edges blend cleanly. Light and dark versions.
  _save(
    _splash(icon, bg: ColorRgba8(0xF4, 0xF6, 0xF5, 255), track: ColorRgba8(0xDC, 0xE5, 0xE0, 255)),
    '../../android/app/src/main/res/drawable-nodpi/splash_logo.png',
  );
  _save(
    _splash(icon, bg: ColorRgba8(0x0F, 0x14, 0x12, 255), track: ColorRgba8(0x26, 0x30, 0x2B, 255)),
    '../../android/app/src/main/res/drawable-night-nodpi/splash_logo.png',
  );

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

/// The launch picture: a 96 dp icon, a 28 dp gap and a 140 x 4 dp bar,
/// centred as one group on a 288 dp canvas (4 px per dp) of colour [bg].
Image _splash(Image icon, {required Color bg, required Color track}) {
  const dp = 4;
  const canvas = 288 * dp;
  const centre = canvas ~/ 2;
  final out = Image(width: canvas, height: canvas, numChannels: 4)..clear(bg);
  // The group is 128 dp tall, so the icon's centre is 16 dp above the
  // canvas centre and the bar's centre 62 dp below it.
  const iconSize = 96 * dp;
  compositeImage(
    out,
    copyResize(icon, width: iconSize, height: iconSize, interpolation: Interpolation.cubic),
    dstX: centre - iconSize ~/ 2,
    dstY: centre - 16 * dp - iconSize ~/ 2,
  );
  fillRect(
    out,
    x1: centre - 70 * dp,
    y1: centre + 60 * dp,
    x2: centre + 70 * dp,
    y2: centre + 64 * dp,
    color: track,
    radius: 2 * dp,
  );
  return out;
}

String _hex(Color c) =>
    [c.r, c.g, c.b].map((v) => v.toInt().toRadixString(16).padLeft(2, '0')).join().toUpperCase();

void _save(Image image, String name) => _write(image, '$out/$name');

void _write(Image image, String path) {
  File(path).writeAsBytesSync(encodePng(image));
  stdout.writeln('wrote $path (${image.width}x${image.height})');
}
