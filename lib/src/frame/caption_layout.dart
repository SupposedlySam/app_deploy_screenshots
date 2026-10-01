import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

import 'frame_geometry.dart';
import 'marketing_frame.dart';

/// A frame's caption, laid out for one canvas.
class CaptionLayout {
  CaptionLayout._(this._lines, this._unit);

  /// Lays out [frame]'s caption across [width] canvas pixels, at [unit]
  /// canvas pixels per layout point.
  factory CaptionLayout.of(MarketingFrame frame, double width, double unit) {
    final caption = frame.caption;
    if (caption == null) return CaptionLayout._(const [], unit);
    final ink = frame.background.brightness == Brightness.light
        ? const Color(0xFF111111)
        : const Color(0xFFFFFFFF);

    TextPainter line(String text, TextStyle base, TextStyle? custom) {
      final style = base.merge(custom);
      // Caption sizes are points; scale every metric to canvas pixels.
      final scaled = style.copyWith(
        fontSize: (style.fontSize ?? 14) * unit,
        letterSpacing: style.letterSpacing == null
            ? null
            : style.letterSpacing! * unit,
      );
      return TextPainter(
        text: TextSpan(text: text, style: scaled),
        textAlign: caption.textAlign,
        textDirection: caption.textDirection,
      )..layout(minWidth: width, maxWidth: width);
    }

    return CaptionLayout._([
      line(
        caption.headline,
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.15,
          color: ink,
        ),
        caption.headlineStyle,
      ),
      if (caption.subheadline != null)
        line(
          caption.subheadline!,
          TextStyle(
            fontFamily: 'Roboto',
            fontSize: 17,
            height: 1.3,
            color: ink.withValues(alpha: 0.72),
          ),
          caption.subheadlineStyle,
        ),
    ], unit);
  }

  final List<TextPainter> _lines;
  final double _unit;

  bool get isEmpty => _lines.isEmpty;

  /// Height of the whole block, in canvas pixels.
  double get height => _lines.isEmpty
      ? 0
      : _lines.fold<double>(0, (h, p) => h + p.height) +
            FrameGeometry.lineGap * _unit * (_lines.length - 1);

  /// Area covered by text, in canvas pixels squared: the line boxes, not
  /// the layout box, since a short headline centred in a wide box covers
  /// only what it inks.
  double get textArea => _lines.fold<double>(
    0,
    (sum, p) =>
        sum +
        p.computeLineMetrics().fold<double>(
          0,
          (a, l) => a + l.width * l.height,
        ),
  );

  void paint(Canvas canvas, Offset topLeft) {
    var y = topLeft.dy;
    for (final p in _lines) {
      p.paint(canvas, Offset(topLeft.dx, y));
      y += p.height + FrameGeometry.lineGap * _unit;
    }
  }
}
