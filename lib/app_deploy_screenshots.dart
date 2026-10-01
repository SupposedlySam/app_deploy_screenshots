import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_deploy_screenshots/device.dart';
import 'package:app_deploy_screenshots/src/annotations.dart';
import 'package:app_deploy_screenshots/src/capture/capture_session.dart';
import 'package:app_deploy_screenshots/src/capture/capture_request.dart';
import 'package:app_deploy_screenshots/src/capture/screen_capturer.dart';
import 'package:app_deploy_screenshots/src/screenshot_pipeline.dart';
import 'package:app_deploy_screenshots/src/frame/marketing_frame.dart';
import 'package:app_deploy_screenshots/src/output/output_paths.dart';
import 'package:app_deploy_screenshots/src/output/report.dart';
import 'package:app_deploy_screenshots/src/setup/channel_mocks.dart';
import 'package:app_deploy_screenshots/src/setup/fonts.dart';
import 'package:app_deploy_screenshots/src/status_bar.dart';
import 'package:app_deploy_screenshots/src/variant.dart';

export 'device.dart';
export 'extensions.dart';
export 'src/annotations.dart'
    show
        ScreenshotAnnotation,
        Spotlight,
        Callout,
        CalloutPlacement,
        MagnifierInset,
        MagnifierShape,
        Lift;
export 'src/capture/screen_capturer.dart' show CustomPump, DeviceSetup;
export 'src/frame/device_style.dart'
    show
        DeviceStyle,
        DeviceBezel,
        DeviceOutline,
        DeviceGlow,
        ScreenCutout,
        ScreenCrop;
export 'src/frame/frame_layout.dart' show FrameLayout;
export 'src/frame/caption.dart'
    show
        Caption,
        CaptionEmphasis,
        EmphasisColor,
        EmphasisStyle,
        EmphasisMarker,
        EmphasisGradient;
export 'src/frame/marketing_frame.dart'
    show ScreenshotFrame, MarketingFrame, FrameBackground;
export 'src/output/png_encoder.dart' show encodeOpaquePng;
export 'src/output/report.dart' show ScreenshotRecord, ScreenshotSource;
export 'src/setup/fonts.dart' show TestAssetBundle;
export 'src/status_bar.dart' show StatusBarOverlay;
export 'src/variant.dart' show ScreenshotVariant, ScreenshotContext;

/// Function definition for allowing for custom file name building
typedef FileNameBuilder = String Function(Device device);

/// Store screenshots from widget tests.
///
/// The static methods here are the whole public surface. They delegate to
/// the capture pipeline in `src/`: setup, capture, framing and output.
class AppDeployScreenshots {
  static final _session = CaptureSession.shared;
  static final _pipeline = ScreenshotPipeline(_session);

  /// Comprehensive setup for screenshot tests with font loading and configuration
  ///
  /// This should be called in your `flutter_test_config.dart` or in `setUpAll`
  ///
  /// [loadFonts] - Whether to load custom fonts (recommended: true)
  /// [verbose] - Whether to print detailed setup information
  /// [mockPlatformChannels] - Whether to mock common platform channels
  /// [loadEmojiFont] - Whether to load [emojiFontFamily] (see [loadEmojiFont])
  static Future<void> initialize({
    bool loadFonts = true,
    bool verbose = false,
    bool mockPlatformChannels = true,
    bool loadEmojiFont = true,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (verbose) debugPrint('🚀 Initializing screenshot test environment...');

    if (loadFonts) await loadAppFonts(verbose: verbose, skipOnError: true);

    try {
      await FontSetup.loadTextFont();
    } catch (e) {
      // Printed even when not verbose: captions would fall back to the
      // regular-only Roboto, and nothing else would say why.
      debugPrint('⚠️ app_deploy_screenshots: caption font not loaded: $e');
    }

    if (loadEmojiFont) {
      try {
        await AppDeployScreenshots.loadEmojiFont();
        if (verbose) debugPrint('  ✅ Loaded emoji font $emojiFontFamily');
      } catch (e) {
        // Printed even when not verbose: emoji would silently render as
        // boxes, and nothing else would say why.
        debugPrint('⚠️ app_deploy_screenshots: emoji font not loaded: $e');
      }
    }

    if (mockPlatformChannels) ChannelMocks.install(verbose: verbose);

    if (verbose) debugPrint('✅ Screenshot test environment ready!');
  }

  /// Font family of the bundled monochrome emoji font (Noto Emoji, SIL Open
  /// Font License 1.1).
  ///
  /// The test renderer cannot draw colour emoji, and it does not fall back
  /// between fonts on its own, so emoji render as empty boxes. Name this
  /// family as a fallback in the app's theme to draw them as clean outlines:
  ///
  /// ```dart
  /// ThemeData(
  ///   fontFamilyFallback: const [AppDeployScreenshots.emojiFontFamily],
  /// )
  /// ```
  ///
  /// This is safe to leave in a production theme. On a device the family
  /// does not exist, so it is skipped and the system emoji font is used.
  static const String emojiFontFamily = FontSetup.emojiFontFamily;

  /// Loads [emojiFontFamily]. [initialize] calls this by default.
  static Future<void> loadEmojiFont() => FontSetup.loadEmojiFont();

  /// The `lib/` directory of [package] in a parsed `package_config.json`
  /// found at [configUri], or null if it is not listed.
  @visibleForTesting
  static Uri? packageLibFromConfig(
    Uri configUri,
    Object? json,
    String package,
  ) => FontSetup.packageLibFromConfig(configUri, json, package);

  /// Loads every font in the app's `FontManifest.json`, so text renders in
  /// real typefaces instead of the test font's black boxes.
  ///
  /// [verbose] - If true, prints detailed information about font loading progress
  /// [skipOnError] - If true, continues loading other fonts even if one fails
  static Future<void> loadAppFonts({
    bool verbose = false,
    bool skipOnError = true,
  }) => FontSetup.loadAppFonts(verbose: verbose, skipOnError: skipOnError);

  /// Captures [name] on every iOS and Android device in [Device.allDevices],
  /// into `app_deploy_screenshots/<platform>/<size>_<device>/`.
  ///
  /// For upload-ready store sizes only, use [forStores]. For store rules,
  /// see:
  /// * https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/
  /// * https://support.google.com/googleplay/android-developer/answer/9866151
  ///
  /// See [byDevices] for the other parameters.
  static Future<List<ScreenshotRecord>> byPlatform(
    WidgetTester tester,
    String name, {
    Finder? finder,
    CustomPump? customPump,
    DeviceSetup? deviceSetup,
    FileNameBuilder? fileNameBuilder,
    List<ScreenshotVariant> variants = const [ScreenshotVariant.none],
    int? order,
    StatusBarOverlay? statusBar,
    List<ScreenshotAnnotation> annotations = const [],
    ScreenshotFrame? frame,
  }) => _captureAll(
    tester,
    name,
    devices: [
      DevicePlatform.ios,
      DevicePlatform.android,
    ].expand(Device.byPlatform).toList(),
    pathFor: fileNameBuilder == null
        ? OutputPaths.platform
        : (device, context) =>
              OutputPaths.decorate(fileNameBuilder(context.device), context),
    finder: finder,
    customPump: customPump,
    deviceSetup: deviceSetup,
    variants: variants,
    order: order,
    statusBar: statusBar,
    annotations: annotations,
    frame: frame,
  );

  /// Captures [name] at the exact pixel sizes App Store Connect and Google
  /// Play ask for ([Device.appStore] and [Device.playStore]), into
  /// `<root>/<platform>/<device>/`, one folder per upload slot.
  ///
  /// See [byDevices] for the other parameters.
  static Future<List<ScreenshotRecord>> forStores(
    WidgetTester tester,
    String name, {
    List<Device> devices = const [...Device.appStore, ...Device.playStore],
    String root = defaultRoot,
    Finder? finder,
    CustomPump? customPump,
    DeviceSetup? deviceSetup,
    List<ScreenshotVariant> variants = const [ScreenshotVariant.none],
    int? order,
    StatusBarOverlay? statusBar,
    List<ScreenshotAnnotation> annotations = const [],
    ScreenshotFrame? frame,
  }) => _captureAll(
    tester,
    name,
    devices: devices,
    pathFor: (device, context) => OutputPaths.store(root, device, context),
    finder: finder,
    customPump: customPump,
    deviceSetup: deviceSetup,
    variants: variants,
    order: order,
    statusBar: statusBar,
    annotations: annotations,
    frame: frame,
  );

  /// The directory screenshots are written to unless a path says otherwise.
  static const String defaultRoot = OutputPaths.defaultRoot;

  /// Captures [name] on each of [devices] (default: iPhone 16 Pro and iPad
  /// Pro M4), once per variant.
  ///
  /// * [finder] captures one widget instead of the whole screen.
  /// * [customPump] replaces the default `pumpAndSettle`. Use a fixed pump
  ///   for screens that never settle (spinners, pulses).
  /// * [deviceSetup] runs first for every device, under its overrides.
  /// * [fileNameBuilder] chooses the path. By default it is
  ///   `app_deploy_screenshots/<device>.<name>.png`. The [order] prefix and
  ///   variant suffix are added to the file name either way, so
  ///   `home.png` becomes `01_home.dark.png`.
  /// * [variants] renders each device once per [ScreenshotVariant], e.g.
  ///   `[ScreenshotVariant.light, ScreenshotVariant.dark]` or
  ///   `ScreenshotVariant.matrix(...)`.
  /// * [order] is the screenshot's position in the store listing, from 1.
  ///   The stores list screenshots in upload order.
  /// * [statusBar] draws a clean status bar into the top safe area.
  /// * [annotations] draws spotlights, callouts and magnifiers.
  /// * [frame] composites the screenshot into store artwork.
  ///
  /// Returns a record of every image written.
  ///
  /// See also: [byPlatform], [forStores], [byDevice]
  static Future<List<ScreenshotRecord>> byDevices(
    WidgetTester tester,
    String name, {
    Finder? finder,
    CustomPump? customPump,
    DeviceSetup? deviceSetup,
    List<Device>? devices,
    FileNameBuilder? fileNameBuilder,
    List<ScreenshotVariant> variants = const [ScreenshotVariant.none],
    int? order,
    StatusBarOverlay? statusBar,
    List<ScreenshotAnnotation> annotations = const [],
    ScreenshotFrame? frame,
  }) {
    assert(devices == null || devices.isNotEmpty);
    return _captureAll(
      tester,
      name,
      devices: devices ?? const [Device.iphone16Pro, Device.ipadProM4],
      pathFor: fileNameBuilder == null
          ? OutputPaths.flat
          : (device, context) =>
                OutputPaths.decorate(fileNameBuilder(context.device), context),
      finder: finder,
      customPump: customPump,
      deviceSetup: deviceSetup,
      variants: variants,
      order: order,
      statusBar: statusBar,
      annotations: annotations,
      frame: frame,
    );
  }

  /// Captures one screenshot of [device] to [fileName].
  ///
  /// Output is a 24-bit PNG with no alpha channel, as Google Play and App
  /// Store Connect ask for. See [byDevices] for the parameters.
  ///
  /// [fileName] is used exactly as given; [order] and [variant] only
  /// describe the screenshot to builders and the manifest.
  ///
  /// See also: [byPlatform], [byDevices]
  static Future<ScreenshotRecord> byDevice(
    WidgetTester tester,
    String name, {
    required Device device,
    required String fileName,
    Finder? finder,
    DeviceSetup? deviceSetup,
    CustomPump? customPump,
    bool waitForImages = true,
    bool applyDeviceOverrides = true,
    ScreenshotVariant variant = ScreenshotVariant.none,
    int? order,
    StatusBarOverlay? statusBar,
    List<ScreenshotAnnotation> annotations = const [],
    ScreenshotFrame? frame,
  }) async {
    assert(
      !name.endsWith('.png'),
      'Screenshot names should not include file type',
    );
    final context = ScreenshotContext(
      name: name,
      device: variant.applyTo(device),
      variant: variant,
      order: order,
    );
    return _pipeline.screen(
      tester,
      context,
      CaptureRequest(
        finder: finder,
        deviceSetup: deviceSetup,
        customPump: customPump,
        waitForImages: waitForImages,
        applyDeviceOverrides: applyDeviceOverrides,
        statusBar: statusBar,
        annotations: annotations,
        frame: frame,
      ),
      path: fileName,
    );
  }

  static Future<List<ScreenshotRecord>> _captureAll(
    WidgetTester tester,
    String name, {
    required List<Device> devices,
    required String Function(Device device, ScreenshotContext context) pathFor,
    required Finder? finder,
    required CustomPump? customPump,
    required DeviceSetup? deviceSetup,
    required List<ScreenshotVariant> variants,
    required int? order,
    required StatusBarOverlay? statusBar,
    required List<ScreenshotAnnotation> annotations,
    required ScreenshotFrame? frame,
  }) async {
    assert(variants.isNotEmpty);
    assert(order == null || order > 0, 'order starts at 1');
    final records = <ScreenshotRecord>[];
    // Images are primed per device inside the capture, after its pumps.
    // Priming once up front is not enough: a widget laid out again at a new
    // device size (a list tile, a `ResizeImage` keyed by width) requests a
    // new image that nobody waits for, and the capture shows a placeholder.
    for (final device in devices) {
      for (final variant in variants) {
        final context = ScreenshotContext(
          name: name,
          device: variant.applyTo(device),
          variant: variant,
          order: order,
        );
        records.add(
          await byDevice(
            tester,
            name,
            device: device,
            fileName: pathFor(device, context),
            finder: finder,
            customPump: customPump,
            deviceSetup: deviceSetup,
            variant: variant,
            order: order,
            statusBar: statusBar,
            annotations: annotations,
            frame: frame,
          ),
        );
      }
    }
    return records;
  }

  /// Writes review material for everything under [root]: `manifest.json`
  /// and one contact sheet per device folder in `_review/`.
  ///
  /// Also checks Google Play's guidance that text overlays cover no more than
  /// 20% of a screenshot. Every Play screenshot whose caption covers more
  /// than [playCaptionCoverageLimit] is printed and returned. It only warns,
  /// because the guidance is advice rather than an upload check; set the
  /// limit to null to skip it.
  ///
  /// Call it once screenshots are written, e.g. at the end of a test or in
  /// `tearDownAll`. Pass [tester] when calling inside a `testWidgets` body,
  /// so image work runs outside its fake-async zone.
  static Future<List<(String path, double coverage)>> writeReport({
    String root = defaultRoot,
    WidgetTester? tester,
    bool manifest = true,
    bool contactSheets = true,
    int columns = 5,
    double? playCaptionCoverageLimit = 0.2,
  }) async {
    Future<void> write() async {
      if (manifest) await Manifest.write(root, _session.records);
      if (contactSheets) await ContactSheets.write(root, columns: columns);
    }

    await (tester == null ? write() : tester.runAsync(write));

    final limit = playCaptionCoverageLimit;
    if (limit == null || !manifest) return const [];
    final over = Manifest.captionCoverageOver(root, limit);
    for (final (path, coverage) in over) {
      debugPrint(
        '⚠️ app_deploy_screenshots: $path caption covers '
        '${(coverage * 100).toStringAsFixed(1)}% of the image '
        '(Google Play guidance: ${(limit * 100).round()}% or less)',
      );
    }
    return over;
  }

  /// Render the closest [RepaintBoundary] of the [element] into an image.
  ///
  /// [pixelRatio] is image pixels per logical pixel for a boundary below the
  /// root view. The root view's layer is already in physical pixels.
  static Future<ui.Image> captureImage(
    Element element, {
    double pixelRatio = 1,
  }) => ScreenCapturer.captureImage(element, pixelRatio: pixelRatio);

  /// Waits for every [Image] widget and [BoxDecoration] image in the tree to
  /// finish decoding.
  static Future<void> primeAssets(WidgetTester tester) =>
      ScreenCapturer.primeAssets(tester);
}
