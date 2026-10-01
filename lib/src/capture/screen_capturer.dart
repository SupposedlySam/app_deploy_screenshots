import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../device.dart';
import '../../extensions.dart';
import '../annotations.dart';
import '../status_bar.dart';
import '../variant.dart';
import 'annotation_resolver.dart';
import 'capture_request.dart';
import 'capture_session.dart';
import 'image_primer.dart';
import 'captured_screen.dart';

/// Pumps a custom amount before capture, e.g. a fixed duration for screens
/// that never settle.
typedef CustomPump = Future<void> Function(WidgetTester tester);

/// Runs for each device, under its overrides, before the capture.
typedef DeviceSetup = Future<void> Function(Device device, WidgetTester tester);

/// Puts the app into a device's configuration and captures it.
class ScreenCapturer {
  const ScreenCapturer(this.session);

  final CaptureSession session;

  /// Room for three chained `kThemeAnimationDuration` (200 ms) animations.
  static const Duration _themeTransition = Duration(milliseconds: 600);
  static const Duration _frame = Duration(milliseconds: 50);

  Future<CapturedScreen> capture(
    WidgetTester tester,
    ScreenshotContext context,
    CaptureRequest request,
  ) async {
    late CapturedScreen captured;

    Future<void> body() async {
      final locale = context.variant.locale;
      if (locale != null) tester.platformDispatcher.localesTestValue = [locale];
      // flutter_test replaces every elevation shadow with a solid black
      // outline (`debugDisableShadows`), which suits goldens but puts a black
      // ring around every card and FAB in store artwork. Draw real shadows
      // while capturing, and put the test's setting back afterwards.
      final shadowsWereDisabled = debugDisableShadows;
      debugDisableShadows = false;
      _markTreeNeedsPaint(tester);
      try {
        // A brightness change animates the theme, and the animations chain:
        // `AnimatedTheme` runs 200 ms, and only when it lands does
        // `Material`'s `AnimatedDefaultTextStyle` start its own 200 ms
        // towards the new text colour. With a fixed customPump a capture
        // lands mid-way (washed-out colours, text in the previous theme's
        // colour). One long pump is not enough: it finishes the first
        // animation in a single frame and the second only starts there. So
        // step through in frames. pumpAndSettle is no answer either, since
        // many apps never settle.
        if (session.lastBrightness != context.device.brightness) {
          for (var t = Duration.zero; t < _themeTransition; t += _frame) {
            await tester.pump(_frame);
          }
          session.lastBrightness = context.device.brightness;
        }

        await (request.deviceSetup ?? _twoPumps)(context.device, tester);
        await (request.customPump ?? _pumpAndSettle)(tester);

        if (request.waitForImages) {
          await primeAssets(tester);
          // Decoding completes outside the frame; one more frame paints it.
          await tester.pump();
        }

        captured = await _grab(
          tester,
          context.device,
          request.finder,
          request.annotations,
          request.statusBar,
        );
      } finally {
        debugDisableShadows = shadowsWereDisabled;
        _markTreeNeedsPaint(tester);
        if (locale != null) tester.platformDispatcher.clearLocalesTestValue();
      }
    }

    await (request.applyDeviceOverrides
        ? tester.binding.runWithDeviceOverrides(context.device, body: body)
        : body());
    return captured;
  }

  /// Reads everything from the widget tree, then captures the image outside
  /// the fake-async zone.
  Future<CapturedScreen> _grab(
    WidgetTester tester,
    Device device,
    Finder? finder,
    List<ScreenshotAnnotation> annotations,
    StatusBarOverlay? statusBar,
  ) async {
    final resolved = AnnotationResolver.resolve(tester, annotations);
    final element = (finder ?? find.byWidgetPredicate((w) => true))
        .evaluate()
        .first;
    final boundary = repaintBoundaryOf(element);
    final view = tester.view;
    final viewSize = view.physicalSize / view.devicePixelRatio;

    final Rect viewRect;
    final Future<ui.Image> imageFuture;
    if (boundary is RenderView) {
      viewRect = Offset.zero & viewSize;
      imageFuture = captureImage(element);
    } else {
      final box = boundary as RenderBox;
      viewRect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      imageFuture = captureImage(element, pixelRatio: view.devicePixelRatio);
    }

    final icons =
        statusBar?.iconBrightness ??
        statusBarIconsFor(
          tester.binding.renderViews.first.debugLayer
              ?.find<SystemUiOverlayStyle>(
                Offset(
                  view.physicalSize.width / 2,
                  device.safeArea.top * view.devicePixelRatio / 2,
                ),
              ),
          device,
        );

    final image = (await tester.runAsync(() => imageFuture))!;
    return CapturedScreen(
      image: image,
      viewRect: viewRect,
      viewSize: viewSize,
      device: device,
      annotations: resolved,
      statusBarIcons: icons,
    );
  }

  /// The nearest repaint boundary at or above [element].
  static RenderObject repaintBoundaryOf(Element element) {
    RenderObject? renderObject = element.renderObject;
    while (renderObject != null && !renderObject.isRepaintBoundary) {
      renderObject = renderObject.parent;
    }
    if (renderObject == null) {
      throw StateError('No RepaintBoundary found in ancestor chain');
    }
    return renderObject;
  }

  /// Renders the closest repaint boundary of [element] into an image.
  ///
  /// [pixelRatio] is image pixels per logical pixel for a boundary below the
  /// root view. The root view's layer is already in physical pixels.
  static Future<ui.Image> captureImage(
    Element element, {
    double pixelRatio = 1,
  }) {
    assert(element.renderObject != null);
    final renderObject = repaintBoundaryOf(element);
    assert(!renderObject.debugNeedsPaint);
    final layer = renderObject.debugLayer;
    if (layer is! OffsetLayer) {
      throw StateError('Expected OffsetLayer but got ${layer.runtimeType}');
    }
    return layer.toImage(
      renderObject.paintBounds,
      pixelRatio: renderObject is RenderView ? 1 : pixelRatio,
    );
  }

  /// Waits for every [Image] widget and [BoxDecoration] image in the app's
  /// tree to finish decoding.
  static Future<void> primeAssets(WidgetTester tester) =>
      tester.runAsync(() => ImagePrimer.prime(tester.binding.rootElement!));

  static Future<void> _pumpAndSettle(WidgetTester tester) =>
      tester.pumpAndSettle();

  static Future<void> _twoPumps(Device device, WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  static void _markTreeNeedsPaint(WidgetTester tester) {
    void visit(RenderObject o) {
      o.markNeedsPaint();
      o.visitChildren(visit);
    }

    for (final view in tester.binding.renderViews) {
      visit(view);
    }
  }
}
