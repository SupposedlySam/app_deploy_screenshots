import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'marketing_frame.dart';

/// Where the screen sits on the canvas, and how to map points onto it.
///
/// Everything drawn relative to the screen (bezel, annotations lifted off
/// it, magnifiers) goes through this one mapping, so they always line up.
class ScreenPlacement {
  const ScreenPlacement({
    required this.rect,
    required this.angle,
    required this.imageSize,
    required this.viewRect,
  });

  /// The screen, unrotated, in canvas pixels. Rotation is about its centre.
  final Rect rect;

  /// Rotation in radians.
  final double angle;

  /// The screenshot's size in pixels.
  final Size imageSize;

  /// The part of the device's view the screenshot covers, in logical points.
  final Rect viewRect;

  /// Canvas pixels per screenshot pixel.
  double get canvasPerImagePixel => rect.width / imageSize.width;

  /// Canvas pixels per device logical point.
  double get canvasPerPoint => rect.width / viewRect.width;

  /// Maps a point in screenshot pixels to the canvas.
  Offset imageToCanvas(Offset p) {
    final dx = (p.dx - imageSize.width / 2) * canvasPerImagePixel;
    final dy = (p.dy - imageSize.height / 2) * canvasPerImagePixel;
    final c = math.cos(angle), s = math.sin(angle);
    return Offset(
      rect.center.dx + dx * c - dy * s,
      rect.center.dy + dx * s + dy * c,
    );
  }

  /// Maps a point in the device's view (logical points) to the canvas.
  Offset viewToCanvas(Offset p) => imageToCanvas(
    (p - viewRect.topLeft) * (imageSize.width / viewRect.width),
  );
}

/// The resolved layout of one framed slide, in canvas pixels.
class FramePlan {
  const FramePlan({
    required this.canvasSize,
    required this.unit,
    required this.margin,
    required this.captionTop,
    required this.screen,
    required this.bezelWidth,
  });

  final Size canvasSize;

  /// Canvas pixels per layout point (captions, margins, gaps).
  final double unit;

  /// Side margin for captions, in canvas pixels.
  final double margin;

  /// Top of the caption block, in canvas pixels.
  final double captionTop;

  final ScreenPlacement screen;

  /// Bezel thickness, in canvas pixels.
  final double bezelWidth;
}

/// Works out where the caption and the device go. Pure arithmetic, so each
/// layout can be checked with numbers rather than by sampling pixels.
abstract final class FrameGeometry {
  /// Gap between caption lines, in layout points.
  static const double lineGap = 8;

  /// Canvas pixels per layout point for [frame] on [canvasSize]: the canvas
  /// area relative to `referenceSize`, so text covers the same share of
  /// every canvas.
  static double unitFor(MarketingFrame frame, Size canvasSize) => math.sqrt(
    canvasSize.width *
        canvasSize.height /
        (frame.referenceSize.width * frame.referenceSize.height),
  );

  static FramePlan plan({
    required MarketingFrame frame,
    required Size canvasSize,
    required Size imageSize,
    required Rect viewRect,
    required double captionHeight,
  }) {
    final unit = unitFor(frame, canvasSize);
    final margin = 24 * unit;
    final topPad = 48 * unit;
    final gap = captionHeight > 0 ? 28 * unit : 0.0;
    final aspect = imageSize.height / imageSize.width;

    // The bezel is measured in the device's points, at the size the screen is
    // drawn. Before 1.2 it was scaled as if the screen filled the canvas
    // width, which drew it about a third too thick. Its width depends on the
    // screen's, so solve for the screen width with the bezel included:
    // device width = w * (1 + k).
    final bezelPoints = frame.bezel?.width ?? 0;
    final k = 2 * bezelPoints / viewRect.width;

    double w;
    double screenTop;
    var captionTop = topPad;
    switch (frame.layout) {
      case FrameLayout.captionTop:
      case FrameLayout.captionBottom:
        final availW = canvasSize.width - 2 * margin;
        final availH =
            canvasSize.height - topPad - margin - captionHeight - gap;
        w = math.min(availW * 0.86 / (1 + k), availH / (aspect + k));
        final bezel = bezelPoints * w / viewRect.width;
        if (frame.layout == FrameLayout.captionTop) {
          screenTop = topPad + captionHeight + gap + bezel;
        } else {
          screenTop = topPad * 0.6 + bezel;
          captionTop = screenTop + w * aspect + bezel + gap;
        }
      case FrameLayout.tilted:
        w = (canvasSize.width - 2 * margin) * 0.8 / (1 + k);
        final bezel = bezelPoints * w / viewRect.width;
        screenTop = topPad + captionHeight + gap + bezel + 16 * unit;
    }

    final rect = Rect.fromLTWH(
      (canvasSize.width - w) / 2,
      screenTop,
      w,
      w * aspect,
    );
    return FramePlan(
      canvasSize: canvasSize,
      unit: unit,
      margin: margin,
      captionTop: captionTop,
      bezelWidth: bezelPoints * w / viewRect.width,
      screen: ScreenPlacement(
        rect: rect,
        angle: frame.layout == FrameLayout.tilted
            ? frame.tilt * math.pi / 180
            : 0,
        imageSize: imageSize,
        viewRect: viewRect,
      ),
    );
  }
}
