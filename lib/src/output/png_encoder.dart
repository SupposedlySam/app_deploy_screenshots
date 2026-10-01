import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Writes images as 24-bit RGB PNGs with no alpha channel, the format the
/// stores ask for.
abstract final class PngEncoder {
  /// Encodes [image] as a 24-bit RGB PNG with no alpha channel.
  ///
  /// Google Play asks for "JPEG or 24-bit PNG (no alpha)", and App Store Connect
  /// asks for flattened images without transparency. `ui.Image.toByteData(format:
  /// png)` always writes RGBA, so the package encodes its own. Any translucent
  /// pixel is composited over [background] first, so nothing is lost silently.
  static Future<Uint8List> encode(
    ui.Image image, {
    ui.Color background = const ui.Color(0xFFFFFFFF),
  }) async {
    final rgba = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (rgba == null) {
      throw StateError(
        'Could not read pixels from a ${image.width}x${image.height} image',
      );
    }
    return encodeRgba(
      rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
      image.width,
      image.height,
      background: background,
    );
  }

  /// Encodes straight (non-premultiplied) RGBA [pixels] as a 24-bit RGB PNG.
  static Uint8List encodeRgba(
    Uint8List pixels,
    int width,
    int height, {
    ui.Color background = const ui.Color(0xFFFFFFFF),
  }) {
    assert(pixels.length == width * height * 4);
    final bgR = (background.r * 255).round();
    final bgG = (background.g * 255).round();
    final bgB = (background.b * 255).round();

    // Each scanline is a filter-type byte (0 = none) followed by RGB triples.
    final stride = width * 3 + 1;
    final raw = Uint8List(stride * height);
    var i = 0;
    for (var y = 0; y < height; y++) {
      var o = y * stride + 1;
      for (var x = 0; x < width; x++, i += 4, o += 3) {
        final a = pixels[i + 3];
        if (a == 255) {
          raw[o] = pixels[i];
          raw[o + 1] = pixels[i + 1];
          raw[o + 2] = pixels[i + 2];
        } else {
          final inv = 255 - a;
          raw[o] = (pixels[i] * a + bgR * inv) ~/ 255;
          raw[o + 1] = (pixels[i + 1] * a + bgG * inv) ~/ 255;
          raw[o + 2] = (pixels[i + 2] * a + bgB * inv) ~/ 255;
        }
      }
    }

    final header = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 2) // colour type 2: truecolour, no alpha
      ..setUint8(10, 0) // compression
      ..setUint8(11, 0) // filter
      ..setUint8(12, 0); // no interlace

    final out = BytesBuilder(copy: false)
      ..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
    _chunk(out, 'IHDR', header.buffer.asUint8List());
    _chunk(out, 'IDAT', Uint8List.fromList(ZLibEncoder(level: 6).convert(raw)));
    _chunk(out, 'IEND', Uint8List(0));
    return out.takeBytes();
  }
}

/// Encodes [image] as a 24-bit RGB PNG with no alpha channel.
///
/// Google Play asks for "JPEG or 24-bit PNG (no alpha)", and App Store
/// Connect asks for flattened images. Translucent pixels are composited over
/// [background].
Future<Uint8List> encodeOpaquePng(
  ui.Image image, {
  ui.Color background = const ui.Color(0xFFFFFFFF),
}) => PngEncoder.encode(image, background: background);

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final length = ByteData(4)..setUint32(0, data.length);
  out
    ..add(length.buffer.asUint8List())
    ..add(typeBytes)
    ..add(data);
  var crc = _crc32(0xFFFFFFFF, typeBytes);
  crc = _crc32(crc, data) ^ 0xFFFFFFFF;
  out.add((ByteData(4)..setUint32(0, crc)).buffer.asUint8List());
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(int crc, Uint8List bytes) {
  var c = crc;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c;
}
