import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture/capture_request.dart';
import 'capture/capture_session.dart';
import 'capture/screen_capturer.dart';
import 'capture/widget_renderer.dart';
import '../device.dart';
import 'device_mockup.dart';
import 'frame/device_style.dart';
import 'frame/frame_compositor.dart';
import 'frame/frame_decoration.dart';
import 'frame/frame_geometry.dart';
import 'frame/frame_resolution.dart';
import 'frame/marketing_frame.dart';
import 'frame/screen_overlays.dart';
import 'output/output_layout.dart';
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
          textDirection: context.textDirection,
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
            textDirection: context.textDirection,
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

  /// Captures the app as [context] describes, with the status bar and every
  /// annotation drawn on the screen, and returns it instead of writing it.
  Future<ScreenCapture> captureScreen(
    WidgetTester tester,
    ScreenshotContext context,
    CaptureRequest request,
  ) async {
    final captured = await capturer.capture(tester, context, request);
    try {
      final image = (await tester.runAsync(
        () => ScreenOverlays.apply(
          captured,
          statusBar: request.statusBar,
          includeCanvasAnnotations: true,
          textDirection: context.textDirection,
        ),
      ))!;
      return ScreenCapture(image, captured.device, captured.viewRect);
    } finally {
      captured.dispose();
    }
  }

  /// [captureScreen] for every device and variant. The captures are freed
  /// when the test ends.
  Future<ScreenCaptures> captureAll(
    WidgetTester tester, {
    required List<Device> devices,
    required List<ScreenshotVariant> variants,
    required CaptureRequest request,
  }) async {
    final screens = <(String, ScreenshotVariant), ScreenCapture>{};
    final captures = ScreenCaptures(screens);
    addTearDown(captures.dispose);
    for (final device in devices) {
      for (final variant in variants) {
        screens[(device.name, variant)] = await captureScreen(
          tester,
          ScreenshotContext(
            name: 'capture',
            device: variant.applyTo(device),
            variant: variant,
          ),
          request,
        );
      }
    }
    return captures;
  }

  /// [panorama] for every device and variant: [names] left to right,
  /// numbered from [order].
  Future<List<ScreenshotRecord>> panoramaAll(
    WidgetTester tester, {
    required List<String> names,
    required WidgetSlideBuilder builder,
    required List<Device> devices,
    required List<ScreenshotVariant> variants,
    required OutputLayout output,
    required int order,
    Size referenceSize = const Size(440, 956),
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    ThemeData Function(ScreenshotContext shot)? theme,
  }) async {
    assert(names.length >= 2, 'a panorama spans at least two slides');
    assert(order > 0, 'order starts at 1');
    final pathFor = output.pathsFor(devices, variants);
    final records = <ScreenshotRecord>[];
    for (final device in devices) {
      for (final variant in variants) {
        final context = ScreenshotContext(
          name: names.first,
          device: variant.applyTo(device),
          variant: variant,
          order: order,
          source: ScreenshotSource.widget,
          canvasSize: device.pixelSize,
        );
        final slices = [
          for (var i = 0; i < names.length; i++)
            context.copyWith(name: names[i], order: order + i),
        ];
        records.addAll(
          await panorama(
            tester,
            context,
            slices,
            builder,
            paths: [for (final s in slices) pathFor(s.device, s)],
            referenceSize: referenceSize,
            localizationsDelegates: localizationsDelegates,
            theme: theme?.call(context),
          ),
        );
      }
    }
    return records;
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

  /// Renders [builder] once across [slices].length canvases side by side and
  /// writes each slice as its own screenshot: [slices] gives each one's
  /// context (name and order), [paths] where it goes.
  Future<List<ScreenshotRecord>> panorama(
    WidgetTester tester,
    ScreenshotContext context,
    List<ScreenshotContext> slices,
    WidgetSlideBuilder builder, {
    required List<String> paths,
    Size referenceSize = const Size(440, 956),
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    ThemeData? theme,
  }) async {
    assert(slices.length == paths.length && slices.isNotEmpty);
    final canvas = context.canvasSize!;
    final unit = math.sqrt(
      canvas.width *
          canvas.height /
          (referenceSize.width * referenceSize.height),
    );
    final whole = Size(canvas.width * slices.length, canvas.height);
    final wide = context.copyWith(canvasSize: whole);
    final image = await renderer.render(
      tester,
      Builder(builder: (c) => builder(c, wide)),
      logicalSize: whole / unit,
      pixelRatio: unit,
      brightness: context.brightness,
      locale: context.locale,
      localizationsDelegates: localizationsDelegates,
      theme: theme,
    );
    try {
      return (await tester.runAsync(() async {
        final records = <ScreenshotRecord>[];
        for (var i = 0; i < slices.length; i++) {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawImageRect(
            image,
            Rect.fromLTWH(canvas.width * i, 0, canvas.width, canvas.height),
            Offset.zero & canvas,
            Paint(),
          );
          final picture = recorder.endRecording();
          final slice = await picture.toImage(
            canvas.width.round(),
            canvas.height.round(),
          );
          picture.dispose();
          records.add(
            await writer.write(
              slices[i],
              slice,
              path: paths[i],
              source: ScreenshotSource.widget,
            ),
          );
        }
        return records;
      }))!;
    } finally {
      image.dispose();
    }
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
          textDirection: context.textDirection,
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
