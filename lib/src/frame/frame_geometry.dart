import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'frame_resolution.dart';
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
    Rect? sourceRect,
  }) : _sourceRect = sourceRect;

  /// The screen, unrotated, in canvas pixels. Rotation is about its centre.
  final Rect rect;

  /// Rotation in radians.
  final double angle;

  /// The screenshot's size in pixels.
  final Size imageSize;

  /// The part of the device's view the screenshot covers, in logical points.
  final Rect viewRect;

  final Rect? _sourceRect;

  /// The part of the screenshot drawn into [rect], in screenshot pixels:
  /// the whole image, or less when the frame crops it (for example to hide
  /// the status bar).
  Rect get sourceRect => _sourceRect ?? Offset.zero & imageSize;

  /// Canvas pixels per screenshot pixel.
  double get canvasPerImagePixel => rect.width / sourceRect.width;

  /// Canvas pixels per device logical point.
  double get canvasPerPoint =>
      canvasPerImagePixel * imageSize.width / viewRect.width;

  /// Maps a point in screenshot pixels to the canvas.
  Offset imageToCanvas(Offset p) {
    final dx = (p.dx - sourceRect.center.dx) * canvasPerImagePixel;
    final dy = (p.dy - sourceRect.center.dy) * canvasPerImagePixel;
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

  /// Width available to captions, in canvas pixels.
  double get captionWidth => canvasSize.width - 2 * margin;

  final Size canvasSize;

  /// Canvas pixels per layout point (captions, margins, gaps).
  final double unit;

  /// Side margin for captions, in canvas pixels.
  final double margin;

  /// Top of the caption block, in canvas pixels.
  final double captionTop;

  /// Where the screen goes, or null for a slide without a device.
  final ScreenPlacement? screen;

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

  /// Side margin for captions, in canvas pixels.
  static double marginFor(double unit) => 24 * unit;

  /// Width available to captions on [canvasSize], in canvas pixels.
  static double captionWidthFor(MarketingFrame frame, Size canvasSize) =>
      canvasSize.width - 2 * marginFor(unitFor(frame, canvasSize));

  /// Plans a slide. [screen] describes the screenshot, or is null for a
  /// slide with no device (a poster): then the caption sits where it would
  /// above a device and the canvas holds only background, caption and
  /// decorations.
  static FramePlan plan({
    required MarketingFrame frame,
    required Size canvasSize,
    required ScreenSize? screen,
    required double captionHeight,
  }) {
    final unit = unitFor(frame, canvasSize);
    final margin = marginFor(unit);
    final topPad = 48 * unit;
    final gap = captionHeight > 0 ? 28 * unit : 0.0;
    if (screen == null) {
      return FramePlan(
        canvasSize: canvasSize,
        unit: unit,
        margin: margin,
        captionTop: topPad,
        screen: null,
        bezelWidth: 0,
      );
    }
    final viewRect = screen.viewRect;
    final source = screen.sourceRect;
    // Logical points shown: a crop shows fewer than the whole view.
    final shownWidth = viewRect.width * source.width / screen.imageSize.width;
    final aspect = source.height / source.width;

    // The bezel is measured in the device's points, at the size the screen is
    // drawn. Before 1.2 it was scaled as if the screen filled the canvas
    // width, which drew it about a third too thick. Its width depends on the
    // screen's, so solve for the screen width with the bezel included:
    // device width = w * (1 + k).
    final bezelPoints = frame.effectiveDevice.bezel?.width ?? 0;
    final k = 2 * bezelPoints / shownWidth;
    final spec = frame.layout.spec;

    double w;
    double screenTop;
    var captionTop = topPad;
    if (!spec.bleeds) {
      // The whole device fits inside the canvas.
      final availW = canvasSize.width - 2 * margin;
      final availH = canvasSize.height - topPad - margin - captionHeight - gap;
      w = math.min(availW * 0.86 / (1 + k), availH / (aspect + k));
      final bezel = bezelPoints * w / shownWidth;
      if (spec.captionFirst) {
        screenTop = topPad + captionHeight + gap + bezel;
      } else {
        screenTop = topPad * 0.6 + bezel;
        captionTop = screenTop + w * aspect + bezel + gap;
      }
    } else {
      // Caption on top; the device runs off the bottom edge. A tilted
      // device gets a little more room so its raised corner clears the
      // caption.
      final lift = frame.effectiveAngle == 0 ? 0.0 : 16 * unit;
      final minTop = topPad + captionHeight + gap + lift;
      w = canvasSize.width * spec.bleedWidth! / (1 + k);
      double deviceTop;
      if (spec.bleedVisible case final visible?) {
        // Device height = w * (aspect + k). Move it down until [visible] of
        // it is on the canvas; if that would reach into the caption, make
        // it smaller instead, keeping [visible].
        deviceTop = canvasSize.height - visible * w * (aspect + k);
        if (deviceTop < minTop) {
          w = (canvasSize.height - minTop) / (visible * (aspect + k));
          deviceTop = minTop;
        }
      } else {
        deviceTop = minTop;
      }
      screenTop = deviceTop + bezelPoints * w / shownWidth;
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
      bezelWidth: bezelPoints * w / shownWidth,
      screen: ScreenPlacement(
        rect: rect,
        angle: frame.effectiveAngle * math.pi / 180,
        imageSize: screen.imageSize,
        viewRect: viewRect,
        sourceRect: source,
      ),
    );
  }
}

/// A screenshot as the geometry sees it: its pixel size, the view area it
/// covers, and the part of it to show.
class ScreenSize {
  ScreenSize({
    required this.imageSize,
    required this.viewRect,
    Rect? sourceRect,
  }) : sourceRect = sourceRect ?? Offset.zero & imageSize;

  final Size imageSize;
  final Rect viewRect;
  final Rect sourceRect;
}
