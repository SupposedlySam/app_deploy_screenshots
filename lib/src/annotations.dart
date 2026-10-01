import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture/captured_screen.dart';
import 'frame/frame_geometry.dart';

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
) => AnnotationPainter.resolve(tester, annotations);

/// Resolves and paints annotations. Annotations draw in one of two places:
/// on the screenshot itself (spotlights, callouts), so they scale and rotate
/// with it, or on the output canvas (magnifiers), so they stay sharp and can
/// extend past the device. The exhaustive switches below make adding an
/// annotation type a compile error until it is placed in one of them.
abstract final class AnnotationPainter {
  static List<ResolvedAnnotation> resolve(
    WidgetTester tester,
    List<ScreenshotAnnotation> annotations,
  ) => [for (final a in annotations) ResolvedAnnotation(a, _rectOf(tester, a))];

  /// Paints the screenshot-level annotations in the view's logical
  /// coordinates.
  static void paintOnScreen(
    Canvas canvas,
    Size view,
    List<ResolvedAnnotation> resolved,
  ) {
    final spotlights = <(Spotlight, Rect)>[];
    final callouts = <(Callout, Rect)>[];
    for (final r in resolved) {
      switch (r.annotation) {
        case final Spotlight s:
          spotlights.add((s, r.rect));
        case final Callout c:
          callouts.add((c, r.rect));
        case MagnifierInset():
          break; // canvas level
      }
    }
    // All spotlights share one scrim, so overlapping holes don't darken it.
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
    for (final (c, rect) in callouts) {
      _paintCallout(canvas, view, c, rect);
    }
  }

  /// Paints the canvas-level annotations onto an output canvas of
  /// [canvasSize], where [placement] says how the screenshot sits on it.
  static void paintOnCanvas(
    Canvas canvas, {
    required CapturedScreen captured,
    required ScreenPlacement placement,
    required Size canvasSize,
  }) {
    for (final r in captured.annotations) {
      switch (r.annotation) {
        case final MagnifierInset m:
          _paintMagnifier(canvas, m, r.rect, captured, placement, canvasSize);
        case Spotlight() || Callout():
          break; // screenshot level
      }
    }
  }
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

void _paintMagnifier(
  Canvas canvas,
  MagnifierInset m,
  Rect target,
  CapturedScreen captured,
  ScreenPlacement placement,
  Size output,
) {
  final outputPerLogical = placement.canvasPerPoint;
  var region = m.padding.inflateRect(target);
  if (m.shape == MagnifierShape.circle) {
    region = Rect.fromCircle(
      center: region.center,
      radius: region.longestSide / 2,
    );
  }
  final src = Rect.fromPoints(
    captured.viewToImage(region.topLeft),
    captured.viewToImage(region.bottomRight),
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
  var centre =
      placement.viewToCanvas(region.center) + m.offset * outputPerLogical;
  centre = Offset(
    _clampCentre(centre.dx, size.width / 2 + border + margin, output.width),
    _clampCentre(centre.dy, size.height / 2 + border + margin, output.height),
  );
  final dst = Rect.fromCenter(
    center: centre,
    width: size.width,
    height: size.height,
  );

  Path outline(Rect r, double extra) => m.shape == MagnifierShape.circle
      ? (Path()..addOval(r))
      : (Path()..addRRect(
          RRect.fromRectAndRadius(
            r,
            Radius.circular(m.radius * outputPerLogical + extra),
          ),
        ));
  final shape = outline(dst, 0);
  final outer = outline(dst.inflate(border), border);

  canvas.drawShadow(
    outer,
    const Color(0xFF000000),
    12 * outputPerLogical,
    false,
  );
  canvas.drawPath(outer, Paint()..color = m.borderColor);
  canvas
    ..save()
    ..clipPath(shape)
    ..drawImageRect(
      captured.image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    )
    ..restore();
}

double _clampCentre(double value, double half, double extent) =>
    half * 2 >= extent
    ? extent / 2
    : value.clamp(half, extent - half).toDouble();
