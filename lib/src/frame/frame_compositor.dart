import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'annotation_painter.dart';
import '../capture/captured_screen.dart';
import 'caption_layout.dart';
import 'frame_geometry.dart';
import 'marketing_frame.dart';

/// A finished frame: the canvas image and what was measured on it.
class ComposedFrame {
  ComposedFrame(this.image, this.captionCoverage);

  final ui.Image image;

  /// Share of the canvas covered by caption text, 0–1.
  final double captionCoverage;
}

/// The screenshot going into a frame.
class FrameScreen {
  FrameScreen({required this.image, required this.captured, this.sourceRect});

  /// The screenshot with the status bar and on-screen annotations drawn.
  final ui.Image image;

  /// The raw capture, for anything sampled from the unannotated screen.
  final CapturedScreen captured;

  /// The part of [image] to show, in pixels; null for all of it.
  final Rect? sourceRect;
}

/// Everything a layer can read while painting.
class FrameLayerContext {
  FrameLayerContext({
    required this.frame,
    required this.plan,
    required this.caption,
    required this.screen,
  });

  final MarketingFrame frame;
  final FramePlan plan;
  final CaptionLayout caption;

  /// The screenshot, or null for a slide without a device.
  final FrameScreen? screen;
}

/// One stage of the frame, painted in order onto the canvas.
abstract interface class FrameLayer {
  Future<void> paint(Canvas canvas, FrameLayerContext context);
}

/// Composites a screenshot into a [MarketingFrame] by painting [layers] in
/// order. A new visual element is a new layer, not another branch in one
/// long function.
class FrameCompositor {
  const FrameCompositor([this.layers = defaultLayers]);

  static const List<FrameLayer> defaultLayers = [
    _BackgroundLayer(),
    _CaptionLayer(),
    _DeviceLayer(),
    _CanvasAnnotationLayer(),
  ];

  final List<FrameLayer> layers;

  /// Composes [frame] onto a [canvasSize] canvas, around [screen] if given.
  Future<ComposedFrame> compose({
    required MarketingFrame frame,
    required Size canvasSize,
    FrameScreen? screen,
  }) async {
    final unit = FrameGeometry.unitFor(frame, canvasSize);
    final caption = CaptionLayout.of(
      frame,
      FrameGeometry.captionWidthFor(frame, canvasSize),
      unit,
    );
    final plan = FrameGeometry.plan(
      frame: frame,
      canvasSize: canvasSize,
      screen: screen == null
          ? null
          : ScreenSize(
              imageSize: Size(
                screen.image.width.toDouble(),
                screen.image.height.toDouble(),
              ),
              viewRect: screen.captured.viewRect,
              sourceRect: screen.sourceRect,
            ),
      captionHeight: caption.height,
    );

    final context = FrameLayerContext(
      frame: frame,
      plan: plan,
      caption: caption,
      screen: screen,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & canvasSize);
    for (final layer in layers) {
      await layer.paint(canvas, context);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasSize.width.round(),
      canvasSize.height.round(),
    );
    picture.dispose();
    return ComposedFrame(
      image,
      caption.textArea / (canvasSize.width * canvasSize.height),
    );
  }
}

class _BackgroundLayer implements FrameLayer {
  const _BackgroundLayer();

  @override
  Future<void> paint(Canvas canvas, FrameLayerContext context) =>
      context.frame.background.fill(canvas, context.plan.canvasSize);
}

class _CaptionLayer implements FrameLayer {
  const _CaptionLayer();

  @override
  Future<void> paint(Canvas canvas, FrameLayerContext context) async {
    context.caption.paint(
      canvas,
      Offset(context.plan.margin, context.plan.captionTop),
    );
  }
}

class _DeviceLayer implements FrameLayer {
  const _DeviceLayer();

  @override
  Future<void> paint(Canvas canvas, FrameLayerContext context) async {
    final screen = context.screen;
    final placement = context.plan.screen;
    if (screen == null || placement == null) return;
    final frame = context.frame;
    final unit = context.plan.unit;
    final device = screen.captured.device;
    final radiusPoints =
        frame.screenCornerRadius ??
        (device.screenCornerRadius > 0 ? device.screenCornerRadius : 16);
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: placement.rect.width,
      height: placement.rect.height,
    );
    final screenShape = RRect.fromRectAndRadius(
      local,
      Radius.circular(radiusPoints * placement.canvasPerPoint),
    );
    final outer = screenShape.inflate(context.plan.bezelWidth);

    canvas
      ..save()
      ..translate(placement.rect.center.dx, placement.rect.center.dy)
      ..rotate(placement.angle);
    if (frame.shadow) {
      canvas.drawRRect(
        outer.shift(Offset(0, 12 * unit)),
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * unit),
      );
    }
    if (frame.bezel != null) {
      canvas.drawRRect(outer, Paint()..color = frame.bezel!.color);
    }
    canvas
      ..clipRRect(screenShape)
      ..drawImageRect(
        screen.image,
        placement.sourceRect,
        local,
        Paint()..filterQuality = FilterQuality.high,
      )
      ..restore();
  }
}

class _CanvasAnnotationLayer implements FrameLayer {
  const _CanvasAnnotationLayer();

  @override
  Future<void> paint(Canvas canvas, FrameLayerContext context) async {
    final screen = context.screen;
    final placement = context.plan.screen;
    if (screen == null || placement == null) return;
    AnnotationPainter.paintOnCanvas(
      canvas,
      captured: screen.captured,
      placement: placement,
      canvasSize: context.plan.canvasSize,
    );
  }
}
