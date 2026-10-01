import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 4x4 solid red PNG, small enough to inline in tests.
final Uint8List redPng = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, //
  0, 0, 0, 4, 8, 2, 0, 0, 0, 38, 147, 9, 41, 0, 0, 0, 16, 73, 68, 65, 84, //
  120, 156, 99, 248, 207, 192, 0, 71, 12, 196, 113, 0, 174, 147, 15, 241, //
  208, 95, 35, 158, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

/// A decoded PNG with pixel access, for asserting on what a screenshot shows.
class DecodedPng {
  DecodedPng._(this.width, this.height, this._rgba);

  final int width;
  final int height;
  final ByteData _rgba;

  /// Reads the pixels of an in-memory [image] and disposes it.
  static Future<DecodedPng> fromImage(
    WidgetTester tester,
    ui.Image image,
  ) async {
    return (await tester.runAsync(() async {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final png = DecodedPng._(image.width, image.height, rgba!);
      image.dispose();
      return png;
    }))!;
  }

  static Future<DecodedPng> read(WidgetTester tester, String path) async {
    final bytes = File(path).readAsBytesSync();
    return (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return DecodedPng._(image.width, image.height, rgba!);
    }))!;
  }

  Color pixel(int x, int y) {
    final o = (y * width + x) * 4;
    return Color.fromARGB(
      _rgba.getUint8(o + 3),
      _rgba.getUint8(o),
      _rgba.getUint8(o + 1),
      _rgba.getUint8(o + 2),
    );
  }

  /// Centre of mass of the pixels that satisfy [test], or null if none do.
  Offset? centroid(bool Function(Color) test, {int step = 2}) {
    var sx = 0.0, sy = 0.0, n = 0;
    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        if (test(pixel(x, y))) {
          sx += x;
          sy += y;
          n++;
        }
      }
    }
    return n == 0 ? null : Offset(sx / n, sy / n);
  }

  /// Bounding box of the pixels that satisfy [test], or null if none do.
  Rect? bounds(bool Function(Color) test, {int step = 1}) {
    double? l, t, r, b;
    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        if (!test(pixel(x, y))) continue;
        l = l == null || x < l ? x.toDouble() : l;
        r = r == null || x > r ? x.toDouble() : r;
        t ??= y.toDouble();
        b = y.toDouble();
      }
    }
    return l == null ? null : Rect.fromLTRB(l, t!, r!, b!);
  }

  /// Fraction of pixels in [rect] (image pixels) that satisfy [test].
  double fraction(Rect rect, bool Function(Color) test, {int step = 4}) {
    var hit = 0, total = 0;
    for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y += step) {
      for (var x = rect.left.toInt(); x < rect.right.toInt(); x += step) {
        total++;
        if (test(pixel(x, y))) hit++;
      }
    }
    assert(total > 0, 'empty sample rect $rect');
    return hit / total;
  }
}

bool isRed(Color c) =>
    (c.r * 255) > 200 && (c.g * 255) < 60 && (c.b * 255) < 60;
