import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../setup/fonts.dart';
import '../variant.dart';
import 'image_primer.dart';

/// Renders a widget into an image in its own pipeline, without touching the
/// app under test. The app's widget tree, state and position in a flow are
/// left as they were, so a hero slide can sit between two screenshots.
class WidgetRenderer {
  const WidgetRenderer();

  /// Renders [widget] at [logicalSize] and [pixelRatio], so the image is
  /// `logicalSize * pixelRatio` pixels.
  ///
  /// The widget gets what an app would give it, so `Text` and Material
  /// widgets work with no app around them:
  /// * a [MediaQuery] for that size, [brightness] and [padding];
  /// * [Localizations] from [localizationsDelegates], or the default widgets
  ///   and Material ones (English only) when none are given;
  /// * text direction from the delegates, or from [locale] without them
  ///   (right-to-left for Arabic, Hebrew, Persian and Urdu);
  /// * a [Theme]: [theme], or a default one in [brightness].
  ///
  /// The result is still artwork: animations are drawn at their first
  /// frame. The tree is unmounted afterwards, so state is disposed.
  Future<ui.Image> render(
    WidgetTester tester,
    Widget widget, {
    required Size logicalSize,
    required double pixelRatio,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en', 'US'),
    EdgeInsets padding = EdgeInsets.zero,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    ThemeData? theme,
  }) async {
    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: tester.view,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logicalSize),
        physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
        devicePixelRatio: pixelRatio,
      ),
      // The view's tight constraints go straight to the boundary, so the
      // widget fills the canvas whatever its intrinsic size.
      child: boundary,
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final focus = FocusManager();
    final buildOwner = BuildOwner(focusManager: focus);
    var mounted = false;

    Widget content = Theme(
      // The bundled Roboto, in real weights, unless the caller brings a
      // theme of their own.
      data:
          theme ??
          ThemeData(
            brightness: brightness,
            fontFamily: FontSetup.textFontFamily,
          ),
      child: _MountSignal(onMount: () => mounted = true, child: widget),
    );
    if (localizationsDelegates == null) {
      // The default delegates are English-only and always left-to-right,
      // so set the direction from the locale. Real delegates already know
      // it for every locale, so they are left to decide.
      content = Directionality(
        textDirection: ScreenshotContext.directionOf(locale),
        child: content,
      );
    }

    final adapter = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: MediaQuery(
        data: MediaQueryData(
          size: logicalSize,
          devicePixelRatio: pixelRatio,
          platformBrightness: brightness,
          padding: padding,
          viewPadding: padding,
        ),
        // Still artwork: animations stay on their first frame, and no
        // ticker is left running after the slide is drawn.
        child: TickerMode(
          enabled: false,
          child: Localizations(
            locale: locale,
            delegates: [
              ...?localizationsDelegates,
              // Always available, so Text and Material widgets have
              // what they need in English whatever else is passed.
              DefaultWidgetsLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
            ],
            child: content,
          ),
        ),
      ),
    );
    // Attaching mounts the tree, which starts each localization delegate's
    // load. In real time, not the test's fake-async zone, so a delegate's
    // timers and I/O complete as they would in an app, without pumping the
    // app under test.
    final root = (await tester.runAsync(
      () async => adapter.attachToRenderTree(buildOwner),
    ))!;

    void frame() {
      buildOwner
        ..buildScope(root)
        ..finalizeTree();
      pipeline
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
    }

    try {
      frame();
      // Localizations build a placeholder until every delegate has loaded,
      // which can take more than one turn of the event loop (deferred or
      // asset-backed delegates). Wait until the widget itself is mounted.
      final deadline = DateTime.now().add(localizationsTimeout);
      while (!mounted) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError(
            'Localizations for $locale did not finish loading within '
            '${localizationsTimeout.inSeconds} s, so the slide would be '
            'blank. Check the localizationsDelegates passed in.',
          );
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        frame();
      }
      // Images decode asynchronously; wait for them, then paint again.
      await tester.runAsync(() => ImagePrimer.prime(root));
      frame();
      final target = Size(
        (logicalSize.width * pixelRatio).roundToDouble(),
        (logicalSize.height * pixelRatio).roundToDouble(),
      );
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        return _exactly(image, target);
      }))!;
    } finally {
      // Unmount: detach the child, then build, so states are disposed and
      // tickers stopped. Attaching alone only schedules the change.
      RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
      ).attachToRenderTree(buildOwner, root);
      buildOwner
        ..buildScope(root)
        ..finalizeTree();
      renderView.child = null;
      pipeline.rootNode = null;
      pipeline.dispose();
      focus.dispose();
    }
  }

  /// How long to wait for localizations before giving up.
  static const Duration localizationsTimeout = Duration(seconds: 5);

  /// [image] at exactly [size] pixels. `toImage` rounds the logical size
  /// times the pixel ratio up, so floating-point error can add a pixel; the
  /// stores need exact dimensions, so redraw onto the exact size then.
  static Future<ui.Image> _exactly(ui.Image image, Size size) async {
    if (image.width == size.width && image.height == size.height) {
      return image;
    }
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final exact = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    picture.dispose();
    image.dispose();
    return exact;
  }
}

/// Calls [onMount] when its subtree is first built: proof the widget is on
/// screen rather than behind a Localizations placeholder.
class _MountSignal extends StatefulWidget {
  const _MountSignal({required this.onMount, required this.child});
  final VoidCallback onMount;
  final Widget child;

  @override
  State<_MountSignal> createState() => _MountSignalState();
}

class _MountSignalState extends State<_MountSignal> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
