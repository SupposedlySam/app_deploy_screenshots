import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../device.dart';
import 'device_style.dart';

/// Draws a device: glow, shadow, buttons, bezel, the screen, its cutout and
/// an outline, with an optional fade. Shared by frames and `DeviceMockup`,
/// so both draw exactly the same device.
abstract final class DevicePainter {
  /// Paints [image]'s [sourceRect] as the screen of [device], [screenSize]
  /// canvas pixels, centred on [centre] and turned by [angle] radians.
  ///
  /// [perPoint] is canvas pixels per device point (bezel, corners, cutout,
  /// buttons); [unit] is canvas pixels per caption point (shadow).
  static void paint(
    Canvas canvas, {
    required ui.Image image,
    required Rect sourceRect,
    required Size screenSize,
    required Offset centre,
    required double angle,
    required Device device,
    required DeviceStyle style,
    required double perPoint,
    required double unit,
  }) {
    final radiusPoints =
        style.cornerRadius ??
        (device.screenCornerRadius > 0 ? device.screenCornerRadius : 16);
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: screenSize.width,
      height: screenSize.height,
    );
    final screenShape = RRect.fromRectAndRadius(
      local,
      Radius.circular(radiusPoints * perPoint),
    );
    final outer = screenShape.inflate((style.bezel?.width ?? 0) * perPoint);

    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(angle);
    if (style.fadeOut > 0) {
      canvas.saveLayer(outer.outerRect.inflate(64 * unit), Paint());
    }

    if (style.glow case final glow?) {
      canvas.drawRRect(
        outer,
        Paint()
          ..color = glow.color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.outer,
            glow.radius * perPoint,
          ),
      );
    }
    if (style.shadow case final shadow?) {
      canvas.drawRRect(
        outer.shift(Offset(0, shadow.offset * unit)),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blur * unit),
      );
    }
    if (style.bezel case final bezel?) {
      if (style.buttons) {
        _paintButtons(canvas, outer, device.platform, perPoint, bezel.color);
      }
      canvas.drawRRect(outer, Paint()..color = bezel.color);
    }

    canvas
      ..save()
      ..clipRRect(screenShape)
      ..drawImageRect(
        image,
        sourceRect,
        local,
        Paint()..filterQuality = FilterQuality.high,
      );
    // A cutout sits over the status bar, so not when that is cropped away.
    if (!style.crop.hidesStatusBarOn(device)) {
      _paintCutout(
        canvas,
        style.cutout.shapeFor(device),
        local,
        perPoint,
        style.bezel?.color ?? const Color(0xFF000000),
      );
    }
    canvas.restore();

    if (style.outline case final outline?) {
      canvas.drawRRect(
        outer,
        Paint()
          ..color = outline.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = outline.width * perPoint,
      );
    }

    if (style.fadeOut > 0) {
      // Keep the device where the mask is opaque, fading out towards the
      // bottom. dstIn multiplies what was drawn by the mask's alpha.
      final fadeTop = outer.bottom - outer.height * style.fadeOut;
      canvas
        ..drawRect(
          outer.outerRect.inflate(64 * unit),
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = ui.Gradient.linear(
              Offset(0, fadeTop),
              Offset(0, outer.bottom),
              const [Color(0xFF000000), Color(0x00000000)],
            ),
        )
        ..restore();
    }
    canvas.restore();
  }

  /// Draws side buttons sticking out of [outer] by 2.5 pt: on iPhone the
  /// action and volume buttons on the left and power on the right; on
  /// Android, power and volume on the right. Positions are fractions of the
  /// device height, so they suit any size.
  static void _paintButtons(
    Canvas canvas,
    RRect outer,
    DevicePlatform platform,
    double perPoint,
    Color bezel,
  ) {
    final paint = Paint()
      ..color = Color.lerp(bezel, const Color(0xFF808080), 0.25)!;
    final depth = 2.5 * perPoint;
    final h = outer.height;
    void button(bool left, double from, double to) {
      final x = left ? outer.left - depth : outer.right - depth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x,
            outer.top + h * from,
            x + depth * 2,
            outer.top + h * to,
          ),
          Radius.circular(depth),
        ),
        paint,
      );
    }

    if (platform == DevicePlatform.ios) {
      button(true, 0.17, 0.21); // action
      button(true, 0.25, 0.32); // volume up
      button(true, 0.34, 0.41); // volume down
      button(false, 0.26, 0.37); // power
    } else {
      button(false, 0.20, 0.27); // power
      button(false, 0.31, 0.43); // volume
    }
  }

  /// Draws [shape] at the top centre of [screen], sized in device points.
  static void _paintCutout(
    Canvas canvas,
    CutoutShape shape,
    Rect screen,
    double perPoint,
    Color color,
  ) {
    final paint = Paint()..color = color;
    final cx = screen.center.dx;
    switch (shape) {
      case CutoutShape.none:
        return;
      case CutoutShape.island:
        // iPhone 15/16 Pro Dynamic Island: 126 x 37 pt, 11 pt from the top.
        final w = 126 * perPoint, h = 37 * perPoint;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w / 2, screen.top + 11 * perPoint, w, h),
            Radius.circular(h / 2),
          ),
          paint,
        );
      case CutoutShape.notch:
        // Notched iPhones: about 210 x 30 pt, flush with the top edge.
        final w = 210 * perPoint, h = 30 * perPoint;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - w / 2, screen.top, w, h),
            bottomLeft: Radius.circular(20 * perPoint),
            bottomRight: Radius.circular(20 * perPoint),
          ),
          paint,
        );
      case CutoutShape.punchHole:
        // A centred front camera, 12 pt across, 12 pt from the top.
        canvas.drawCircle(
          Offset(cx, screen.top + 12 * perPoint),
          6 * perPoint,
          paint,
        );
    }
  }
}
