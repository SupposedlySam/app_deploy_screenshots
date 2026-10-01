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
  /// The widget gets what an app would give it, so `Text` and Material
  /// widgets work with no app around them:
  /// * a [MediaQuery] for that size, [brightness] and [padding];
  /// * [Directionality] from [locale] (right-to-left for Arabic, Hebrew,
  ///   Persian and Urdu);
  /// * [Localizations] from [localizationsDelegates], or the default widgets
  ///   and Material ones (English only) when none are given;
  /// * a [Theme]: [theme], or a default one in [brightness].
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
        child: Localizations(
          locale: locale,
          delegates: [
            ...?localizationsDelegates,
            // Always available, so a delegate list without them still
            // gives Text and Material widgets what they need in English.
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
          ],
          // Inside Localizations, which sets its own direction from the
          // widgets localizations (left-to-right for the defaults).
          child: Directionality(
            textDirection: directionOf(locale),
            child: Theme(
              data: theme ?? ThemeData(brightness: brightness),
              child: widget,
            ),
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
      // Localizations load asynchronously when a delegate isn't synchronous.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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

  /// Text direction for [locale].
  static TextDirection directionOf(Locale locale) =>
      const {'ar', 'he', 'fa', 'ur', 'ps', 'yi'}.contains(locale.languageCode)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
