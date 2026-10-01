import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../capture/captured_screen.dart';
import 'annotation_painter.dart';
import 'caption_layout.dart';
import 'device_painter.dart';
import 'frame_decoration.dart';
import 'frame_geometry.dart';
import 'frame_resolution.dart';
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
    required this.widgetImages,
  });

  final MarketingFrame frame;
  final FramePlan plan;
  final CaptionLayout caption;

  /// The screenshot, or null for a slide without a device.
  final FrameScreen? screen;

  /// Widget decorations, already rendered (widgets need the test binding,
  /// so they are rendered before composing).
  final Map<WidgetDecoration, ui.Image> widgetImages;

  /// Area covered by decorations marked as text, in canvas pixels squared.
  double decorationTextArea = 0;

  /// Where [decoration] of [size] canvas pixels goes on the canvas.
  Rect place(FrameDecoration decoration, Size size) {
    final inner = (Offset.zero & plan.canvasSize).deflate(plan.margin);
    return decoration.alignment
        .inscribe(size, inner)
        .shift(decoration.offset * plan.unit);
  }
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
    _DecorationLayer(behindDevice: true),
    _CaptionLayer(),
    _DeviceLayer(),
    _CanvasAnnotationLayer(),
    _DecorationLayer(behindDevice: false),
  ];

  final List<FrameLayer> layers;

  /// Composes [frame] onto a [canvasSize] canvas, around [screen] if given.
  Future<ComposedFrame> compose({
    required MarketingFrame frame,
    required Size canvasSize,
    FrameScreen? screen,
    Map<WidgetDecoration, ui.Image> widgetImages = const {},
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final unit = FrameGeometry.unitFor(frame, canvasSize);
    final caption = CaptionLayout.of(
      frame,
      FrameGeometry.captionWidthFor(frame, canvasSize),
      unit,
      textDirection: textDirection,
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
      widgetImages: widgetImages,
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
      (caption.textArea + context.decorationTextArea) /
          (canvasSize.width * canvasSize.height),
    );
  }
}

class _BackgroundLayer implements FrameLayer {
  const _BackgroundLayer();

  @override
  Future<void> paint(Canvas canvas, FrameLayerContext context) =>
      context.frame.background.fill(
        canvas,
        context.plan.canvasSize,
        unit: context.plan.unit,
        screen: context.screen?.image,
      );
}

class _DecorationLayer implements FrameLayer {
  const _DecorationLayer({required this.behindDevice});

  final bool behindDevice;

  @override
  Future<void> paint(Canvas canvas, FrameLayerContext context) async {
    final unit = context.plan.unit;
    for (final d in context.frame.decorations) {
      if (d.behindDevice != behindDevice) continue;
      switch (d) {
        case final ImageDecoration image:
          final codec = await ui.instantiateImageCodec(image.bytes);
          final decoded = (await codec.getNextFrame()).image;
          final width = image.width * unit;
          final size = Size(width, width * decoded.height / decoded.width);
          canvas.drawImageRect(
            decoded,
            Offset.zero &
                Size(decoded.width.toDouble(), decoded.height.toDouble()),
            context.place(d, size),
            Paint()..filterQuality = FilterQuality.high,
          );
          decoded.dispose();
          if (d.countsAsText) {
            context.decorationTextArea += size.width * size.height;
          }
        case final WidgetDecoration widget:
          final rendered = context.widgetImages[widget];
          if (rendered == null) {
            throw StateError(
              'FrameDecoration.widget was not rendered before composing. '
              'Widget decorations need the test binding; compose through '
              'AppDeployScreenshots.',
            );
          }
          final size = widget.size * unit;
          canvas.drawImageRect(
            rendered,
            Offset.zero &
                Size(rendered.width.toDouble(), rendered.height.toDouble()),
            context.place(d, size),
            Paint()..filterQuality = FilterQuality.high,
          );
          if (widget.countsAsText) {
            context.decorationTextArea += size.width * size.height;
          }
      }
    }
  }
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
    DevicePainter.paint(
      canvas,
      image: screen.image,
      sourceRect: placement.sourceRect,
      screenSize: placement.rect.size,
      centre: placement.rect.center,
      angle: placement.angle,
      device: screen.captured.device,
      style: context.frame.effectiveDevice,
      perPoint: placement.canvasPerPoint,
      unit: context.plan.unit,
    );
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
