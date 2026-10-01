import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../device.dart';
import '../capture/captured_screen.dart';
import 'annotation_painter.dart';
import 'caption_layout.dart';
import 'device_style.dart';
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
    if (style.shadow case final shadow?) {
      canvas.drawRRect(
        outer.shift(Offset(0, shadow.offset * unit)),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blur * unit),
      );
    }
    if (style.bezel case final bezel?) {
      if (style.buttons) {
        _paintButtons(canvas, outer, device.platform, perPoint, bezel.color);
      }
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
    if (!style.crop.hidesStatusBarOn(device)) {
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

  /// Draws side buttons sticking out of [outer] by 2.5 pt: on iPhone the
  /// action and volume buttons on the left and power on the right; on
  /// Android, power and volume on the right. Positions are fractions of the
  /// device height, so they suit any size.
  static void _paintButtons(
    Canvas canvas,
    RRect outer,
    DevicePlatform platform,
    double perPoint,
    Color bezel,
  ) {
    final paint = Paint()
      ..color = Color.lerp(bezel, const Color(0xFF808080), 0.25)!;
    final depth = 2.5 * perPoint;
    final h = outer.height;
    void button(bool left, double from, double to) {
      final x = left ? outer.left - depth : outer.right - depth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x,
            outer.top + h * from,
            x + depth * 2,
            outer.top + h * to,
          ),
          Radius.circular(depth),
        ),
        paint,
      );
    }

    if (platform == DevicePlatform.ios) {
      button(true, 0.17, 0.21); // action
      button(true, 0.25, 0.32); // volume up
      button(true, 0.34, 0.41); // volume down
      button(false, 0.26, 0.37); // power
    } else {
      button(false, 0.20, 0.27); // power
      button(false, 0.31, 0.43); // volume
    }
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
