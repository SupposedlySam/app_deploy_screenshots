import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Something drawn over a screenshot, positioned by a [Finder] so it follows
/// the widget on every device size.
///
/// The finder is evaluated after the device's overrides and pumps, and must
/// match at least one widget; the first match is used. A finder that matches
/// nothing throws rather than producing a screenshot with the annotation
/// silently missing.
@immutable
sealed class ScreenshotAnnotation {
  const ScreenshotAnnotation(this.target);

  /// The widget the annotation points at.
  final Finder target;
}

/// Dims everything except [target], drawing the eye to it.
///
/// Several spotlights on one screenshot share a single scrim, each cutting
/// its own hole.
class Spotlight extends ScreenshotAnnotation {
  const Spotlight(
    super.target, {
    this.padding = const EdgeInsets.all(8),
    this.radius = 12,
    this.scrim = const Color(0x99000000),
  });

  /// Space between the widget's bounds and the edge of the hole, in logical
  /// points.
  final EdgeInsets padding;

  /// Corner radius of the hole, in logical points.
  final double radius;

  /// Colour laid over everything outside the hole.
  final Color scrim;
}

/// Where a [Callout] bubble sits relative to its target.
enum CalloutPlacement {
  /// Above the target when it is in the lower half of the screen, else below.
  auto,
  above,
  below,
}

/// A speech bubble with [text] and an arrow pointing at [target].
class Callout extends ScreenshotAnnotation {
  const Callout(
    super.target,
    this.text, {
    this.placement = CalloutPlacement.auto,
    this.style,
    this.color = const Color(0xFF1C1C1E),
    this.maxWidth = 260,
  });

  final String text;
  final CalloutPlacement placement;

  /// Text style in logical points. Defaults to 15pt white Roboto.
  final TextStyle? style;

  /// Bubble fill.
  final Color color;

  /// Widest the bubble may grow before the text wraps, in logical points.
  final double maxWidth;
}

/// The shape of a [MagnifierInset] inset.
enum MagnifierShape { circle, roundedRect }

/// Enlarges [target] into an inset drawn over the screenshot, e.g. to make
/// one message row legible in a store listing.
///
/// Inside a `MarketingFrame` the inset is drawn on the canvas at full canvas
/// resolution, centred on the target, so a wide inset can extend past the
/// edges of the device. Without a frame it is kept inside the screenshot.
class MagnifierInset extends ScreenshotAnnotation {
  const MagnifierInset(
    super.target, {
    this.zoom = 1.4,
    this.shape = MagnifierShape.roundedRect,
    this.padding = const EdgeInsets.all(4),
    this.offset = Offset.zero,
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 3,
    this.radius = 16,
  }) : assert(zoom > 0);

  /// How much larger than on screen, relative to the device.
  final double zoom;
  final MagnifierShape shape;

  /// Extra area around the target to include, in logical points.
  final EdgeInsets padding;

  /// Moves the inset from its default position, in logical points.
  final Offset offset;

  final Color borderColor;

  /// Border width, in logical points.
  final double borderWidth;

  /// Corner radius for [MagnifierShape.roundedRect], in logical points.
  final double radius;
}

/// An annotation together with where its target was on screen, in the
/// view's logical coordinates.
@immutable
class ResolvedAnnotation {
  const ResolvedAnnotation(this.annotation, this.rect);

  final ScreenshotAnnotation annotation;
  final Rect rect;
}

/// Finds every annotation's target under the current device configuration.
List<ResolvedAnnotation> resolveAnnotations(
  WidgetTester tester,
  List<ScreenshotAnnotation> annotations,
) {
  return [
    for (final a in annotations) ResolvedAnnotation(a, _rectOf(tester, a)),
  ];
}

Rect _rectOf(WidgetTester tester, ScreenshotAnnotation a) {
  final matches = a.target.evaluate();
  if (matches.isEmpty) {
    throw StateError(
      '${a.runtimeType} target matched no widgets: ${a.target.describeMatch(Plurality.zero)}',
    );
  }
  return tester.getRect(find.byElementPredicate((e) => e == matches.first));
}

/// Paints spotlights and callouts in the view's logical coordinates.
void paintScreenAnnotations(
  Canvas canvas,
  Size view,
  List<ResolvedAnnotation> resolved,
) {
  final spotlights = [
    for (final r in resolved)
      if (r.annotation case final Spotlight s) (s, r.rect),
  ];
  if (spotlights.isNotEmpty) {
    final scrim = Path()..fillType = PathFillType.evenOdd;
    scrim.addRect(Offset.zero & view);
    for (final (s, rect) in spotlights) {
      scrim.addRRect(
        RRect.fromRectAndRadius(
          s.padding.inflateRect(rect),
          Radius.circular(s.radius),
        ),
      );
    }
    canvas.drawPath(scrim, Paint()..color = spotlights.first.$1.scrim);
  }

  for (final r in resolved) {
    if (r.annotation case final Callout c) {
      _paintCallout(canvas, view, c, r.rect);
    }
  }
}

void _paintCallout(Canvas canvas, Size view, Callout c, Rect target) {
  const margin = 12.0, arrow = 9.0, gap = 4.0;
  const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  final text =
      TextPainter(
        text: TextSpan(
          text: c.text,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            color: Color(0xFFFFFFFF),
            height: 1.25,
          ).merge(c.style),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(
        maxWidth:
            math.min(c.maxWidth, view.width - 2 * margin) - pad.horizontal,
      );
  final bubbleSize = Size(
    text.width + pad.horizontal,
    text.height + pad.vertical,
  );

  final above = switch (c.placement) {
    CalloutPlacement.above => true,
    CalloutPlacement.below => false,
    CalloutPlacement.auto => target.center.dy > view.height / 2,
  };
  final left = (target.center.dx - bubbleSize.width / 2)
      .clamp(margin, math.max(margin, view.width - margin - bubbleSize.width))
      .toDouble();
  final top = above
      ? target.top - gap - arrow - bubbleSize.height
      : target.bottom + gap + arrow;
  final bubble = RRect.fromRectAndRadius(
    Offset(left, top) & bubbleSize,
    const Radius.circular(12),
  );

  // The arrow keeps clear of the rounded corners.
  final tipX = target.center.dx
      .clamp(bubble.left + 20, bubble.right - 20)
      .toDouble();
  final baseY = above ? bubble.bottom : bubble.top;
  final tipY = above ? baseY + arrow : baseY - arrow;
  final path = Path()
    ..addRRect(bubble)
    ..moveTo(tipX - arrow, baseY)
    ..lineTo(tipX, tipY)
    ..lineTo(tipX + arrow, baseY)
    ..close();

  canvas.drawShadow(path, const Color(0xFF000000), 6, false);
  canvas.drawPath(path, Paint()..color = c.color);
  text.paint(canvas, bubble.outerRect.topLeft + Offset(pad.left, pad.top));
}

/// Paints magnifier insets onto an output canvas.
///
/// [toOutput] maps the view's logical coordinates to output pixels, and
/// [outputPerLogical] is output pixels per logical point on the device.
/// [source] is the unannotated capture, [sourceRect] the view rect it covers
/// and [sourcePerLogical] its pixels per logical point.
void paintMagnifiers(
  Canvas canvas, {
  required List<ResolvedAnnotation> resolved,
  required ui.Image source,
  required Rect sourceRect,
  required double sourcePerLogical,
  required Offset Function(Offset) toOutput,
  required double outputPerLogical,
  required Size output,
}) {
  for (final r in resolved) {
    final m = switch (r.annotation) {
      final MagnifierInset m => m,
      _ => null,
    };
    if (m == null) continue;

    var region = m.padding.inflateRect(r.rect);
    if (m.shape == MagnifierShape.circle) {
      region = Rect.fromCircle(
        center: region.center,
        radius: region.longestSide / 2,
      );
    }
    final src = Rect.fromLTRB(
      (region.left - sourceRect.left) * sourcePerLogical,
      (region.top - sourceRect.top) * sourcePerLogical,
      (region.right - sourceRect.left) * sourcePerLogical,
      (region.bottom - sourceRect.top) * sourcePerLogical,
    );

    final border = m.borderWidth * outputPerLogical;
    const margin = 8.0;
    // A full-width row at 1.4x is wider than the canvas; shrink the zoom
    // rather than cropping the inset at the edges.
    final fit = math.min(
      (output.width - 2 * (border + margin)) / region.width,
      (output.height - 2 * (border + margin)) / region.height,
    );
    final scale = math.min(outputPerLogical * m.zoom, fit);
    final size = region.size * scale;
    var centre = toOutput(region.center) + m.offset * outputPerLogical;
    centre = Offset(
      _clampCentre(centre.dx, size.width / 2 + border + margin, output.width),
      _clampCentre(centre.dy, size.height / 2 + border + margin, output.height),
    );
    final dst = Rect.fromCenter(
      center: centre,
      width: size.width,
      height: size.height,
    );

    final shape = m.shape == MagnifierShape.circle
        ? (Path()..addOval(dst))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(
              dst,
              Radius.circular(m.radius * outputPerLogical),
            ),
          ));
    final outer = m.shape == MagnifierShape.circle
        ? (Path()..addOval(dst.inflate(border)))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(
              dst.inflate(border),
              Radius.circular(m.radius * outputPerLogical + border),
            ),
          ));

    canvas.drawShadow(
      outer,
      const Color(0xFF000000),
      12 * outputPerLogical,
      false,
    );
    canvas.drawPath(outer, Paint()..color = m.borderColor);
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawImageRect(
      source,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }
}

double _clampCentre(double value, double half, double extent) =>
    half * 2 >= extent
    ? extent / 2
    : value.clamp(half, extent - half).toDouble();
