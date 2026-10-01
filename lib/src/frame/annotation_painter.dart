import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../annotations.dart';
import '../capture/captured_screen.dart';
import 'frame_geometry.dart';

/// Paints annotations. Annotations draw in one of two places:
/// on the screenshot itself (spotlights, callouts), so they scale and rotate
/// with it, or on the output canvas (magnifiers), so they stay sharp and can
/// extend past the device. The exhaustive switches below make adding an
/// annotation type a compile error until it is placed in one of them.
abstract final class AnnotationPainter {
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
