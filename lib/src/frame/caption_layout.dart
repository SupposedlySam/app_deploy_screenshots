import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../text_style_ext.dart';
import 'caption.dart';
import 'frame_geometry.dart';
import 'marketing_frame.dart';

/// A frame's caption, laid out for one canvas.
class CaptionLayout {
  CaptionLayout._(this._lines, this._unit);

  /// Lays out [frame]'s caption across [width] canvas pixels, at [unit]
  /// canvas pixels per layout point.
  factory CaptionLayout.of(
    MarketingFrame frame,
    double width,
    double unit, {
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final caption = frame.caption;
    if (caption == null) return CaptionLayout._(const [], unit);
    final ink = frame.background.brightness == Brightness.light
        ? const Color(0xFF111111)
        : const Color(0xFFFFFFFF);

    TextStyle scaled(TextStyle base, TextStyle? custom) {
      final style = PackageText.withWeightAxis(base.merge(custom));
      // Caption sizes are points; scale every metric to canvas pixels.
      return style.copyWith(
        fontSize: (style.fontSize ?? 14) * unit,
        letterSpacing: style.letterSpacing == null
            ? null
            : style.letterSpacing! * unit,
      );
    }

    final emphasis = caption.emphasis;
    _CaptionLine line(String text, TextStyle style, {bool parse = true}) {
      final runs = parse && emphasis != null
          ? parseCaptionMarkup(text)
          : [CaptionRun(text)];
      if (parse && emphasis != null && !runs.any((r) => r.emphasized)) {
        // A builder may return a locale's text without markers, so this
        // warns rather than fails.
        debugPrint(
          'app_deploy_screenshots: caption "$text" has emphasis set but no '
          '**markers**.',
        );
      }
      return _CaptionLine.layout(
        runs,
        style,
        emphasis,
        unit: unit,
        width: width,
        textAlign: caption.textAlign,
        textDirection: caption.textDirection ?? textDirection,
      );
    }

    return CaptionLayout._([
      line(
        caption.headline,
        scaled(
          TextStyle(
            fontFamily: PackageText.family,
            fontFamilyFallback: PackageText.fallback,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: ink,
          ),
          caption.headlineStyle,
        ),
      ),
      if (caption.subheadline != null)
        line(
          caption.subheadline!,
          scaled(
            TextStyle(
              fontFamily: PackageText.family,
              fontFamilyFallback: PackageText.fallback,
              fontSize: 17,
              height: 1.3,
              color: ink.withValues(alpha: 0.72),
            ),
            caption.subheadlineStyle,
          ),
        ),
      if (caption.footnote != null)
        line(
          caption.footnote!,
          scaled(
            TextStyle(
              fontFamily: PackageText.family,
              fontFamilyFallback: PackageText.fallback,
              fontSize: 11,
              height: 1.3,
              color: ink.withValues(alpha: 0.55),
            ),
            caption.footnoteStyle,
          ),
          parse: false,
        ),
    ], unit);
  }

  final List<_CaptionLine> _lines;
  final double _unit;

  bool get isEmpty => _lines.isEmpty;

  /// Height of the whole block, in canvas pixels.
  double get height => _lines.isEmpty
      ? 0
      : _lines.fold<double>(0, (h, l) => h + l.painter.height) +
            FrameGeometry.lineGap * _unit * (_lines.length - 1);

  /// Area covered by text, in canvas pixels squared: the line boxes, not
  /// the layout box, since a short headline centred in a wide box covers
  /// only what it inks.
  double get textArea => _lines.fold<double>(
    0,
    (sum, l) =>
        sum +
        l.painter.computeLineMetrics().fold<double>(
          0,
          (a, m) => a + m.width * m.height,
        ),
  );

  void paint(Canvas canvas, Offset topLeft) {
    var y = topLeft.dy;
    for (final l in _lines) {
      l.paint(canvas, Offset(topLeft.dx, y));
      y += l.painter.height + FrameGeometry.lineGap * _unit;
    }
  }
}

/// One caption paragraph and its emphasised ranges.
class _CaptionLine {
  _CaptionLine(this.painter, this.ranges, this.marker, this.unit);

  factory _CaptionLine.layout(
    List<CaptionRun> runs,
    TextStyle style,
    CaptionEmphasis? emphasis, {
    required double unit,
    required double width,
    required TextAlign textAlign,
    required TextDirection textDirection,
  }) {
    final ranges = <TextRange>[];
    var offset = 0;
    for (final r in runs) {
      if (r.emphasized) {
        ranges.add(TextRange(start: offset, end: offset + r.text.length));
      }
      offset += r.text.length;
    }

    TextPainter build(TextStyle? emphasized) => TextPainter(
      text: TextSpan(
        style: style,
        children: [
          for (final r in runs)
            TextSpan(text: r.text, style: r.emphasized ? emphasized : null),
        ],
      ),
      textAlign: textAlign,
      textDirection: textDirection,
    )..layout(minWidth: width, maxWidth: width);

    switch (emphasis) {
      case null:
        return _CaptionLine(build(null), ranges, null, unit);
      case EmphasisColor(:final color):
        return _CaptionLine(build(TextStyle(color: color)), ranges, null, unit);
      case EmphasisStyle(style: final emphasized):
        return _CaptionLine(
          build(_scaled(emphasized, unit)),
          ranges,
          null,
          unit,
        );
      case EmphasisMarker(:final textColor):
        return _CaptionLine(
          build(textColor == null ? null : TextStyle(color: textColor)),
          ranges,
          emphasis,
          unit,
        );
      case EmphasisGradient(:final gradient):
        // A shader needs the words' bounds, known only after layout. The
        // foreground paint doesn't change metrics, so laying out again with
        // it lands the text in the same place.
        final first = build(null);
        final bounds = _bounds(first, ranges);
        if (bounds == null) return _CaptionLine(first, ranges, null, unit);
        return _CaptionLine(
          build(
            TextStyle(
              foreground: Paint()..shader = gradient.createShader(bounds),
            ),
          ),
          ranges,
          null,
          unit,
        );
    }
  }

  final TextPainter painter;
  final List<TextRange> ranges;
  final EmphasisMarker? marker;
  final double unit;

  void paint(Canvas canvas, Offset topLeft) {
    // Painted at the origin, so shaders and boxes share the painter's
    // coordinates.
    canvas
      ..save()
      ..translate(topLeft.dx, topLeft.dy);
    if (marker case final m?) {
      final paint = Paint()..color = m.color;
      for (final range in ranges) {
        for (final box in painter.getBoxesForSelection(
          TextSelection(baseOffset: range.start, extentOffset: range.end),
        )) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              (m.padding * unit).inflateRect(box.toRect()),
              Radius.circular(m.radius * unit),
            ),
            paint,
          );
        }
      }
    }
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  static TextStyle _scaled(TextStyle style, double unit) =>
      PackageText.withWeightAxis(style).copyWith(
        fontSize: style.fontSize == null ? null : style.fontSize! * unit,
        letterSpacing: style.letterSpacing == null
            ? null
            : style.letterSpacing! * unit,
      );

  static Rect? _bounds(TextPainter painter, List<TextRange> ranges) {
    Rect? bounds;
    for (final range in ranges) {
      for (final box in painter.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      )) {
        final r = box.toRect();
        bounds = bounds == null ? r : bounds.expandToInclude(r);
      }
    }
    return bounds;
  }
}
