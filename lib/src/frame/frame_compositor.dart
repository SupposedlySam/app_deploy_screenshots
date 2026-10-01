import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'annotation_painter.dart';
import '../capture/captured_screen.dart';
import 'caption_layout.dart';
import 'device_style.dart';
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
    final style = context.frame.effectiveDevice;
    final unit = context.plan.unit;
    final device = screen.captured.device;
    final perPoint = placement.canvasPerPoint;
    final radiusPoints =
        style.cornerRadius ??
        (device.screenCornerRadius > 0 ? device.screenCornerRadius : 16);
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: placement.rect.width,
      height: placement.rect.height,
    );
    final screenShape = RRect.fromRectAndRadius(
      local,
      Radius.circular(radiusPoints * perPoint),
    );
    final outer = screenShape.inflate(context.plan.bezelWidth);

    canvas
      ..save()
      ..translate(placement.rect.center.dx, placement.rect.center.dy)
      ..rotate(placement.angle);
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
    if (style.shadow) {
      canvas.drawRRect(
        outer.shift(Offset(0, 12 * unit)),
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * unit),
      );
    }
    if (style.bezel case final bezel?) {
      canvas.drawRRect(outer, Paint()..color = bezel.color);
    }

    canvas
      ..save()
      ..clipRRect(screenShape)
      ..drawImageRect(
        screen.image,
        placement.sourceRect,
        local,
        Paint()..filterQuality = FilterQuality.high,
      );
    // A cutout sits over the status bar, so not when that is cropped away.
    if (!style.crop.hidesStatusBar) {
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
