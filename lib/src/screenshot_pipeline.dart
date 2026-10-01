import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture/capture_request.dart';
import 'capture/capture_session.dart';
import 'capture/screen_capturer.dart';
import 'frame/frame_compositor.dart';
import 'frame/screen_overlays.dart';
import 'output/report.dart';
import 'output/slide_writer.dart';
import 'variant.dart';

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

  /// Captures the app as [context] describes and writes it to [path].
  Future<ScreenshotRecord> screen(
    WidgetTester tester,
    ScreenshotContext context,
    CaptureRequest request, {
    required String path,
  }) async {
    final captured = await capturer.capture(tester, context, request);
    try {
      return (await tester.runAsync(() async {
        final frame = request.frame?.resolve(context);
        final screen = await ScreenOverlays.apply(
          captured,
          statusBar: request.statusBar,
          includeCanvasAnnotations: frame == null,
        );
        if (frame == null) return writer.write(context, screen, path: path);

        final composed = await compositor.compose(
          frame: frame,
          canvasSize:
              frame.canvasSize ??
              Size(screen.width.toDouble(), screen.height.toDouble()),
          screen: FrameScreen(image: screen, captured: captured),
        );
        screen.dispose();
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
    }
  }
}
