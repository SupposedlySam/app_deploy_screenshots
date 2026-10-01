import 'dart:math' as math;
import 'frame/frame_resolution.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture/capture_request.dart';
import 'capture/capture_session.dart';
import 'capture/screen_capturer.dart';
import 'capture/widget_renderer.dart';
import 'frame/frame_decoration.dart';
import 'frame/frame_geometry.dart';
import 'frame/marketing_frame.dart';
import 'frame/device_style.dart';
import 'frame/frame_compositor.dart';
import 'frame/screen_overlays.dart';
import 'output/report.dart';
import 'output/slide_writer.dart';
import 'variant.dart';

/// Builds a widget slide. [shot] says which device, locale and brightness
/// it is for.
typedef WidgetSlideBuilder =
    Widget Function(BuildContext context, ScreenshotContext shot);

/// The order of the stages: capture, overlays, frame, write. The public
/// methods are thin front ends that build a [CaptureRequest] and a path and
/// call this.
class ScreenshotPipeline {
  ScreenshotPipeline(this.session)
    : capturer = ScreenCapturer(session),
      writer = SlideWriter(session);

  final CaptureSession session;
  final ScreenCapturer capturer;
  final SlideWriter writer;
  final FrameCompositor compositor = const FrameCompositor();
  final WidgetRenderer renderer = const WidgetRenderer();

  /// Captures the app as [context] describes and writes it to [path].
  Future<ScreenshotRecord> screen(
    WidgetTester tester,
    ScreenshotContext context,
    CaptureRequest request, {
    required String path,
  }) async {
    final captured = await capturer.capture(tester, context, request);
    var widgets = const <WidgetDecoration, ui.Image>{};
    try {
      final frame = request.frame?.resolve(context);
      if (frame != null) {
        widgets = await _renderDecorations(
          tester,
          frame,
          context,
          frame.canvasSize ??
              Size(
                captured.image.width.toDouble(),
                captured.image.height.toDouble(),
              ),
        );
      }
      return (await tester.runAsync(() async {
        final crop = frame?.effectiveDevice.crop ?? ScreenCrop.none;
        final screen = await ScreenOverlays.apply(
          captured,
          // A status bar that the frame crops away isn't worth drawing.
          statusBar: crop.hidesStatusBarOn(captured.device)
              ? null
              : request.statusBar,
          includeCanvasAnnotations: frame == null,
        );
        if (frame == null) return writer.write(context, screen, path: path);

        final ComposedFrame composed;
        try {
          composed = await compositor.compose(
            frame: frame,
            canvasSize:
                frame.canvasSize ??
                Size(screen.width.toDouble(), screen.height.toDouble()),
            widgetImages: widgets,
            screen: FrameScreen(
              image: screen,
              captured: captured,
              sourceRect: crop.sourceRectFor(
                captured.device,
                Size(screen.width.toDouble(), screen.height.toDouble()),
                captured.viewRect,
              ),
            ),
          );
        } finally {
          screen.dispose();
        }
        return writer.write(
          context,
          composed.image,
          path: path,
          framed: true,
          captionCoverage: composed.captionCoverage,
        );
      }))!;
    } finally {
      captured.dispose();
      _dispose(widgets);
    }
  }

  /// Renders [builder] as a whole slide at [context]'s canvas size.
  ///
  /// The widget is laid out in points of [referenceSize] scaled by canvas
  /// area, like captions, so one design covers a phone and a tablet canvas
  /// in the same proportions.
  Future<ScreenshotRecord> widget(
    WidgetTester tester,
    ScreenshotContext context,
    WidgetSlideBuilder builder, {
    required String path,
    Size referenceSize = const Size(440, 956),
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    ThemeData? theme,
  }) async {
    final canvas = context.canvasSize!;
    final unit = math.sqrt(
      canvas.width *
          canvas.height /
          (referenceSize.width * referenceSize.height),
    );
    final image = await renderer.render(
      tester,
      Builder(builder: (c) => builder(c, context)),
      logicalSize: canvas / unit,
      pixelRatio: unit,
      brightness: context.brightness,
      locale: context.locale,
      localizationsDelegates: localizationsDelegates,
      theme: theme,
    );
    return (await tester.runAsync(
      () => writer.write(
        context,
        image,
        path: path,
        source: ScreenshotSource.widget,
      ),
    ))!;
  }

  /// Composes [frame] with no device: background, caption and decorations.
  Future<ScreenshotRecord> poster(
    WidgetTester tester,
    ScreenshotContext context,
    MarketingFrame frame, {
    required String path,
  }) async {
    final canvas = context.canvasSize!;
    final widgets = await _renderDecorations(tester, frame, context, canvas);
    try {
      return (await tester.runAsync(() async {
        final composed = await compositor.compose(
          frame: frame,
          canvasSize: canvas,
          widgetImages: widgets,
          textDirection: WidgetRenderer.directionOf(context.locale),
        );
        return writer.write(
          context,
          composed.image,
          path: path,
          framed: true,
          captionCoverage: composed.captionCoverage,
          source: ScreenshotSource.poster,
        );
      }))!;
    } finally {
      _dispose(widgets);
    }
  }

  /// Renders [frame]'s widget decorations for a [canvas]-sized slide. They
  /// need the test binding, so this runs before composing.
  Future<Map<WidgetDecoration, ui.Image>> _renderDecorations(
    WidgetTester tester,
    MarketingFrame frame,
    ScreenshotContext context,
    Size canvas,
  ) async {
    final unit = FrameGeometry.unitFor(frame, canvas);
    return {
      for (final d in frame.decorations.whereType<WidgetDecoration>())
        d: await renderer.render(
          tester,
          d.child,
          logicalSize: d.size,
          pixelRatio: unit,
          brightness: context.brightness,
          locale: context.locale,
        ),
    };
  }

  static void _dispose(Map<WidgetDecoration, ui.Image> images) {
    for (final image in images.values) {
      image.dispose();
    }
  }
}
