import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../device.dart';
import 'annotations.dart';
import 'capture/capture_request.dart';
import 'capture/capture_session.dart';
import 'capture/screen_capturer.dart';
import 'device_mockup.dart';
import 'frame/marketing_frame.dart';
import 'output/manifest_report.dart';
import 'output/output_layout.dart';
import 'output/report.dart';
import 'screenshot_pipeline.dart';
import 'shot_loop.dart';
import 'status_bar.dart';
import 'variant.dart';

/// A whole store listing, slide by slide, with the shared design written
/// once and the order counted for you.
///
/// ```dart
/// final listing = StoreListing(
///   tester,
///   frame: MarketingFrame(background: brandGradient, layout: FrameLayout.bleed()),
///   statusBar: const StatusBarOverlay(),
///   customPump: (t) => t.pump(const Duration(milliseconds: 100)),
/// );
///
/// await listing.poster('welcome', caption: const Caption(headline: 'Hello'));
/// await listing.screenshot('inbox', caption: const Caption(headline: 'Chats'));
/// await tester.tap(find.text('Maya Chen'));
/// await listing.screenshot(
///   'conversation',
///   caption: const Caption(headline: 'Talk in private'),
///   annotations: [Lift(find.byKey(const Key('photo')))],
/// );
/// await listing.writeReport();
/// ```
///
/// Each slide is numbered in the order it is added (01_, 02_, …), which is
/// the order the stores show them. Everything set on the listing applies to
/// every slide; pass it again on a slide to change it for that slide only.
/// A slide's [caption] (or `captionFor`, for per-locale text) replaces the
/// shared frame's caption text and keeps the rest of the design, including
/// the shared caption's look: its styles are merged under the slide's, and
/// its emphasis and alignment apply unless the slide sets its own. So a
/// listing styles captions once and each slide passes only its words.
///
/// It is the same pipeline as `AppDeployScreenshots.forStores`,
/// `widgetForStores` and `posterForStores`, so the output is identical.
final class StoreListing {
  StoreListing(
    this.tester, {
    this.devices = const [...Device.appStore, ...Device.playStore],
    this.variants = const [ScreenshotVariant.none],
    this.output = const OutputLayout.folders(),
    this.frame,
    this.statusBar,
    this.customPump,
    this.deviceSetup,
    int firstOrder = 1,
  }) : assert(devices.isNotEmpty),
       assert(variants.isNotEmpty),
       assert(firstOrder > 0, 'order starts at 1'),
       _next = firstOrder,
       _pathFor = output.pathsFor(devices, variants);

  final WidgetTester tester;
  final List<Device> devices;
  final List<ScreenshotVariant> variants;
  final OutputLayout output;

  /// The shared design. A slide's caption replaces its caption text.
  final ScreenshotFrame? frame;
  final StatusBarOverlay? statusBar;
  final CustomPump? customPump;
  final DeviceSetup? deviceSetup;

  final _pipeline = ScreenshotPipeline(CaptureSession.shared);
  int _next;
  final OutputPath _pathFor;

  /// The order the next slide will get.
  int get nextOrder => _next;

  /// Every image written by this listing, in order.
  List<ScreenshotRecord> get records => List.unmodifiable(_records);
  final _records = <ScreenshotRecord>[];

  /// Captures the app as it is now, framed with the shared design.
  ///
  /// [caption] (or [captionFor], given the device, locale and brightness)
  /// replaces the shared frame's caption text, styled like it. [frame]
  /// replaces the whole design for this slide: a `MarketingFrame` or a
  /// `ScreenshotFrame.builder`. The other parameters default to the
  /// listing's.
  Future<List<ScreenshotRecord>> screenshot(
    String name, {
    Caption? caption,
    Caption Function(ScreenshotContext shot)? captionFor,
    List<ScreenshotAnnotation> annotations = const [],
    ScreenshotFrame? frame,
    Finder? finder,
    StatusBarOverlay? statusBar,
    CustomPump? customPump,
    DeviceSetup? deviceSetup,
  }) {
    final design = _withCaption(frame ?? this.frame, caption, captionFor);
    return _slide(
      name,
      ScreenshotSource.app,
      (context) => _pipeline.screen(
        tester,
        context,
        CaptureRequest(
          finder: finder,
          customPump: customPump ?? this.customPump,
          deviceSetup: deviceSetup ?? this.deviceSetup,
          statusBar: statusBar ?? this.statusBar,
          annotations: annotations,
          frame: design,
        ),
        path: _pathFor(context.device, context),
      ),
    );
  }

  /// A slide with no device: the shared design's background, the given
  /// caption, and its decorations. [frame] replaces the design for this
  /// slide.
  Future<List<ScreenshotRecord>> poster(
    String name, {
    Caption? caption,
    Caption Function(ScreenshotContext shot)? captionFor,
    ScreenshotFrame? frame,
  }) {
    final design = _withCaption(frame ?? this.frame, caption, captionFor);
    return _slide(name, ScreenshotSource.poster, (context) {
      final resolved = design?.resolve(context);
      if (resolved == null) {
        throw ArgumentError(
          'poster("$name") needs a frame or a caption: the listing has no '
          'frame and none was passed.',
        );
      }
      final shot = context.copyWith(
        canvasSize: resolved.canvasSize ?? context.device.pixelSize,
      );
      return _pipeline.poster(
        tester,
        shot,
        resolved,
        path: _pathFor(shot.device, shot),
      );
    });
  }

  /// A slide drawn by [builder], at the store size. See
  /// `AppDeployScreenshots.widgetForStores`.
  Future<List<ScreenshotRecord>> widget(
    String name, {
    required WidgetSlideBuilder builder,
    Size referenceSize = const Size(440, 956),
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    ThemeData Function(ScreenshotContext shot)? theme,
  }) => _slide(
    name,
    ScreenshotSource.widget,
    (context) => _pipeline.widget(
      tester,
      context.copyWith(canvasSize: context.device.pixelSize),
      builder,
      path: _pathFor(context.device, context),
      referenceSize: referenceSize,
      localizationsDelegates: localizationsDelegates,
      theme: theme?.call(context),
    ),
  );

  /// A panorama across `names.length` consecutive slides. See
  /// `AppDeployScreenshots.panoramaForStores`.
  Future<List<ScreenshotRecord>> panorama(
    List<String> names, {
    required WidgetSlideBuilder builder,
    Size referenceSize = const Size(440, 956),
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    ThemeData Function(ScreenshotContext shot)? theme,
  }) async {
    final order = _next;
    _next += names.length;
    final written = await _pipeline.panoramaAll(
      tester,
      names: names,
      builder: builder,
      devices: devices,
      variants: variants,
      output: output,
      order: order,
      referenceSize: referenceSize,
      localizationsDelegates: localizationsDelegates,
      theme: theme,
    );
    _records.addAll(written);
    return written;
  }

  /// Captures the app on the listing's devices and variants and returns the
  /// screens, for [DeviceMockup]s in a [widget] or [panorama] slide. See
  /// `AppDeployScreenshots.captureScreens`.
  Future<ScreenCaptures> captureScreens({
    Finder? finder,
    List<ScreenshotAnnotation> annotations = const [],
    StatusBarOverlay? statusBar,
    CustomPump? customPump,
    DeviceSetup? deviceSetup,
  }) {
    return _pipeline.captureAll(
      tester,
      devices: devices,
      variants: variants,
      request: CaptureRequest(
        finder: finder,
        customPump: customPump ?? this.customPump,
        deviceSetup: deviceSetup ?? this.deviceSetup,
        statusBar: statusBar ?? this.statusBar,
        annotations: annotations,
      ),
    );
  }

  /// Writes the manifest and contact sheets for this listing's [output],
  /// and checks Google Play's 20% text guidance. See
  /// `AppDeployScreenshots.writeReport`.
  Future<List<(String path, double coverage)>> writeReport({
    bool manifest = true,
    bool contactSheets = true,
    int columns = 5,
    double? playCaptionCoverageLimit = 0.2,
  }) => ManifestReport.write(
    tester: tester,
    root: output.root,
    session: CaptureSession.shared,
    manifest: manifest,
    contactSheets: contactSheets,
    columns: columns,
    playCaptionCoverageLimit: playCaptionCoverageLimit,
  );

  Future<List<ScreenshotRecord>> _slide(
    String name,
    ScreenshotSource source,
    Future<ScreenshotRecord> Function(ScreenshotContext context) shoot,
  ) async {
    final order = _next++;
    final written = await ShotLoop.run(
      name,
      devices: devices,
      variants: variants,
      order: order,
      source: source,
      canvasFor: (_) => null,
      shoot: shoot,
    );
    _records.addAll(written);
    return written;
  }

  /// [design] with its caption replaced, per screenshot.
  static ScreenshotFrame? _withCaption(
    ScreenshotFrame? design,
    Caption? caption,
    Caption Function(ScreenshotContext shot)? captionFor,
  ) {
    assert(
      caption == null || captionFor == null,
      'Pass caption or captionFor, not both.',
    );
    if (caption == null && captionFor == null) return design;
    return ScreenshotFrame.builder((context) {
      final text = captionFor?.call(context) ?? caption;
      final base = design?.resolve(context) ?? const MarketingFrame();
      return base.copyWith(caption: text?.styledLike(base.caption));
    });
  }
}
