import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'image_primer.dart';

/// Renders a widget into an image in its own pipeline, without touching the
/// app under test. The app's widget tree, state and position in a flow are
/// left as they were, so a hero slide can sit between two screenshots.
class WidgetRenderer {
  const WidgetRenderer();

  /// Renders [widget] at [logicalSize] and [pixelRatio], so the image is
  /// `logicalSize * pixelRatio` pixels.
  ///
  /// The widget gets a [MediaQuery] for that size, the given [brightness],
  /// [locale] and [padding], plus [Directionality] and the default widgets
  /// and Material localizations, so `Text` and most Material widgets work
  /// without an app around them.
  Future<ui.Image> render(
    WidgetTester tester,
    Widget widget, {
    required Size logicalSize,
    required double pixelRatio,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en', 'US'),
    EdgeInsets padding = EdgeInsets.zero,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: tester.view,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logicalSize),
        physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
        devicePixelRatio: pixelRatio,
      ),
      child: RenderPositionedBox(child: boundary),
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    final root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: MediaQuery(
        data: MediaQueryData(
          size: logicalSize,
          devicePixelRatio: pixelRatio,
          platformBrightness: brightness,
          padding: padding,
          viewPadding: padding,
        ),
        child: Directionality(
          textDirection: textDirection,
          child: Localizations(
            locale: locale,
            delegates: const [
              DefaultWidgetsLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
            ],
            child: widget,
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

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
      // Images decode asynchronously; wait for them, then paint again.
      await tester.runAsync(() => ImagePrimer.prime(root));
      frame();
      return (await tester.runAsync(
        () => boundary.toImage(pixelRatio: pixelRatio),
      ))!;
    } finally {
      // Unmount the tree so its state and listeners don't leak.
      RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
      ).attachToRenderTree(buildOwner, root);
      buildOwner.finalizeTree();
      renderView.child = null;
      pipeline.rootNode = null;
    }
  }
}
