import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../device.dart';
import 'text_style_ext.dart';

/// Draws a clean status bar into the top safe-area inset: `9:41`, full
/// signal, full Wi-Fi, full battery. That is the look store screenshots use,
/// and a widget test otherwise has no status bar at all.
///
/// The icons are plain vector shapes, so no platform assets or licensed fonts
/// are needed. Nothing is drawn on a device whose `safeArea.top` is 0.
///
/// The icon colour follows the app, as it would on a phone: the package reads
/// the [SystemUiOverlayStyle] the app publishes at the status bar (an
/// `AppBar`, or an `AnnotatedRegion<SystemUiOverlayStyle>`). With no style
/// published, icons contrast with the platform brightness. Set
/// [iconBrightness] to override.
@immutable
class StatusBarOverlay {
  const StatusBarOverlay({
    this.time = '9:41',
    this.iconBrightness,
    this.style,
    this.fontFamily = PackageText.family,
    this.batteryLevel = 1.0,
  }) : assert(batteryLevel >= 0 && batteryLevel <= 1);

  /// The clock text. `9:41` is Apple's own marketing time.
  final String time;

  /// [Brightness.dark] draws dark icons (for a light background),
  /// [Brightness.light] draws light icons. Null reads it from the app.
  final Brightness? iconBrightness;

  /// Which platform's layout to draw. Null follows `Device.platform`.
  final DevicePlatform? style;

  /// Font for the clock. Defaults to the Roboto that ships with this
  /// package.
  final String fontFamily;

  /// Battery fill, 0–1.
  final double batteryLevel;

  /// Paints the bar in the view's logical coordinates, with (0, 0) at the
  /// top-left of the screen.
  void paint(Canvas canvas, Device device, {required Brightness icons}) {
    final height = device.safeArea.top;
    if (height <= 0) return;
    final color = icons == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final width = device.size.width;
    if ((style ?? device.platform) == DevicePlatform.ios) {
      _paintIos(canvas, width, height, color);
    } else {
      _paintAndroid(canvas, width, height, color);
    }
  }

  void _paintIos(Canvas canvas, double width, double height, Color color) {
    // A notched or Dynamic Island iPhone centres the clock and the icons in
    // the two "ears" beside the cutout. iPads and older iPhones align them to
    // the edges of a short bar.
    final ears = height >= 44 && width < 600;
    final cy = ears ? math.min(height / 2, 30.0) : height / 2;
    final clock = _text(time, ears ? 17 : 14, FontWeight.w600, color);

    if (ears) {
      clock.paint(
        canvas,
        Offset(width * 0.18 - clock.width / 2, cy - clock.height / 2),
      );
    } else {
      clock.paint(canvas, Offset(width < 600 ? 16 : 20, cy - clock.height / 2));
    }

    final cluster = <_Icon>[
      _Icon(18, (c, o) => _iosSignal(c, o, color)),
      _Icon(16, (c, o) => _wifi(c, o, 16, color)),
      _Icon(27, (c, o) => _iosBattery(c, o, color)),
    ];
    const gap = 5.0;
    final clusterWidth =
        cluster.fold<double>(0, (w, i) => w + i.width) +
        gap * (cluster.length - 1);
    var x = ears
        ? width * 0.82 - clusterWidth / 2
        : width - (width < 600 ? 16 : 20) - clusterWidth;
    for (final icon in cluster) {
      icon.paint(canvas, Offset(x, cy));
      x += icon.width + gap;
    }
  }

  void _paintAndroid(Canvas canvas, double width, double height, Color color) {
    final cy = height / 2;
    final clock = _text(time, 14, FontWeight.w500, color);
    clock.paint(canvas, Offset(16, cy - clock.height / 2));

    final cluster = <_Icon>[
      _Icon(16, (c, o) => _wifi(c, o, 16, color)),
      _Icon(14, (c, o) => _androidSignal(c, o, color)),
      _Icon(8, (c, o) => _androidBattery(c, o, color)),
    ];
    const gap = 6.0;
    final clusterWidth =
        cluster.fold<double>(0, (w, i) => w + i.width) +
        gap * (cluster.length - 1);
    var x = width - 16 - clusterWidth;
    for (final icon in cluster) {
      icon.paint(canvas, Offset(x, cy));
      x += icon.width + gap;
    }
  }

  TextPainter _text(String text, double size, FontWeight weight, Color color) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: PackageText.withWeightAxis(
            TextStyle(
              fontFamily: fontFamily,
              fontSize: size,
              fontWeight: weight,
              color: color,
              height: 1.0,
              fontFamilyFallback: PackageText.fallback,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  // Each icon paints with `o` at its left edge, vertically centred.

  void _iosSignal(Canvas canvas, Offset o, Color color) {
    const barWidth = 3.0, spacing = 1.8;
    const heights = [4.0, 6.5, 9.0, 11.5];
    final paint = Paint()..color = color;
    for (var i = 0; i < heights.length; i++) {
      final left = o.dx + i * (barWidth + spacing);
      final bottom = o.dy + heights.last / 2;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          bottom - heights[i],
          left + barWidth,
          bottom,
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  void _wifi(Canvas canvas, Offset o, double width, Color color) {
    // Three concentric arcs over a wedge, opening upwards, drawn as filled
    // annular sectors so they read at any scale.
    final centre = Offset(o.dx + width / 2, o.dy + width * 0.36);
    final paint = Paint()..color = color;
    const sweep = math.pi / 2;
    const start = -math.pi / 2 - sweep / 2;
    final radii = [width * 0.64, width * 0.43, width * 0.22];
    const thickness = 0.13;
    for (final r in radii.take(2)) {
      final inner = r - width * thickness;
      final path = Path()
        ..arcTo(Rect.fromCircle(center: centre, radius: r), start, sweep, true)
        ..arcTo(
          Rect.fromCircle(center: centre, radius: inner),
          start + sweep,
          -sweep,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    final dot = Path()
      ..moveTo(centre.dx, centre.dy)
      ..arcTo(
        Rect.fromCircle(center: centre, radius: radii.last),
        start,
        sweep,
        false,
      )
      ..close();
    canvas.drawPath(dot, paint);
  }

  void _iosBattery(Canvas canvas, Offset o, Color color) {
    const bodyWidth = 24.5, bodyHeight = 12.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx, o.dy - bodyHeight / 2, bodyWidth, bodyHeight),
      const Radius.circular(3.8),
    );
    canvas.drawRRect(
      body.deflate(0.5),
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final inner = body.deflate(2);
    canvas.drawRRect(
      RRect.fromLTRBR(
        inner.left,
        inner.top,
        inner.left + inner.width * batteryLevel,
        inner.bottom,
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        o.dx + bodyWidth + 1,
        o.dy - 2,
        o.dx + bodyWidth + 2.5,
        o.dy + 2,
        const Radius.circular(1),
      ),
      Paint()..color = color.withValues(alpha: 0.4),
    );
  }

  void _androidSignal(Canvas canvas, Offset o, Color color) {
    const size = 14.0;
    final path = Path()
      ..moveTo(o.dx, o.dy + size / 2)
      ..lineTo(o.dx + size, o.dy + size / 2)
      ..lineTo(o.dx + size, o.dy - size / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _androidBattery(Canvas canvas, Offset o, Color color) {
    const w = 8.0, h = 14.0;
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(o.dx + 2.5, o.dy - h / 2, 3, 1.5), paint);
    final body = Rect.fromLTWH(o.dx, o.dy - h / 2 + 1.5, w, h - 1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(1.2)),
      Paint()..color = color.withValues(alpha: 0.35),
    );
    final filled = body.height * batteryLevel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(body.left, body.bottom - filled, body.right, body.bottom),
        const Radius.circular(1.2),
      ),
      paint,
    );
  }
}

class _Icon {
  _Icon(this.width, this.paint);
  final double width;
  final void Function(Canvas canvas, Offset leftCentre) paint;
}

/// The icon brightness a real device would use for [device]'s status bar:
/// the [SystemUiOverlayStyle] the app publishes there, else a contrast with
/// the platform brightness.
Brightness statusBarIconsFor(SystemUiOverlayStyle? published, Device device) {
  if (published != null) {
    // Android states the icon brightness; iOS states the brightness of the
    // bar *behind* the icons, which is the inverse. Prefer the field for the
    // platform being drawn, and fall back to the other.
    final ios = device.platform == DevicePlatform.ios;
    final iconField = published.statusBarIconBrightness;
    final barField = published.statusBarBrightness;
    final fromBar = barField == null
        ? null
        : (barField == Brightness.light ? Brightness.dark : Brightness.light);
    final resolved = ios ? (fromBar ?? iconField) : (iconField ?? fromBar);
    if (resolved != null) return resolved;
  }
  return device.brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
}
