import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_deploy_screenshots/device.dart';
import 'package:app_deploy_screenshots/extensions.dart';
import 'package:app_deploy_screenshots/src/annotations.dart';
import 'package:app_deploy_screenshots/src/marketing_frame.dart';
import 'package:app_deploy_screenshots/src/png_encoder.dart';
import 'package:app_deploy_screenshots/src/report.dart';
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
        MagnifierShape;
export 'src/marketing_frame.dart'
    show
        ScreenshotFrame,
        MarketingFrame,
        FrameLayout,
        FrameBackground,
        Caption,
        DeviceBezel;
export 'src/png_encoder.dart' show encodeOpaquePng;
export 'src/report.dart' show ScreenshotRecord;
export 'src/status_bar.dart' show StatusBarOverlay;
export 'src/variant.dart' show ScreenshotVariant, ScreenshotContext;

///CustomPump is a function that lets you do custom pumping before golden evaluation.
///Sometimes, you want to do a golden test for different stages of animations, so its crucial to have a precise control over pumps and durations
typedef CustomPump = Future<void> Function(WidgetTester);

/// Function definition for allowing for device or test setup to occur for each device configuration under test
typedef DeviceSetup = Future<void> Function(Device device, WidgetTester tester);

/// Function definition for allowing for custom file name building
typedef FileNameBuilder = String Function(Device device);

class AppDeployScreenshots {
  static const List<String> _overridableFonts = [
    'Roboto',
    'GoogleSans',
    'GoogleSansDisplay',
    '.SF UI Display',
    '.SF UI Text',
    '.SF Pro Text',
    '.SF Pro Display',
  ];

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

    _verbosePrint('🚀 Initializing screenshot test environment...', verbose);

    // Load fonts for better text rendering
    if (loadFonts) {
      await loadAppFonts(verbose: verbose, skipOnError: true);
    }

    if (loadEmojiFont) {
      try {
        await AppDeployScreenshots.loadEmojiFont();
        _verbosePrint('  ✅ Loaded emoji font $emojiFontFamily', verbose);
      } catch (e) {
        // Printed even when not verbose: emoji would silently render as
        // boxes, and nothing else would say why.
        debugPrint('⚠️ app_deploy_screenshots: emoji font not loaded: $e');
      }
    }

    // Mock common platform channels that might interfere with tests
    if (mockPlatformChannels) {
      _setupCommonChannelMocks(verbose: verbose);
    }

    _verbosePrint('✅ Screenshot test environment ready!', verbose);
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
  ///   textTheme: ...,
  ///   fontFamilyFallback: const [AppDeployScreenshots.emojiFontFamily],
  /// )
  /// ```
  ///
  /// This is safe to leave in a production theme. On a device the family
  /// does not exist, so it is skipped and the system emoji font is used.
  static const String emojiFontFamily = 'AppDeployScreenshotsEmoji';

  /// Loads [emojiFontFamily]. [initialize] calls this by default.
  ///
  /// The font ships inside the package's `lib/` and is read from disk, not
  /// declared under `flutter: fonts:`. A font declared there would be
  /// bundled into every app that depends on this package, and at 2 MB that
  /// is too much to add to a release build for a test-only feature.
  static Future<void> loadEmojiFont() async {
    final lib = _packageLibDirectory();
    final bytes = await File(
      '${lib.path}/src/fonts/NotoEmoji.ttf',
    ).readAsBytes();
    final loader = FontLoader(emojiFontFamily)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  /// This package's `lib/` directory, found through the nearest
  /// `.dart_tool/package_config.json` above the working directory.
  ///
  /// `Isolate.resolvePackageUri` would be the obvious call, but
  /// `flutter_tester` throws `Unsupported operation` for it. `flutter test`
  /// runs from the package root, and pub workspaces keep the config at the
  /// workspace root, so walking up covers both.
  static Directory _packageLibDirectory() {
    for (Directory? dir = Directory.current; dir != null;) {
      final config = File('${dir.path}/.dart_tool/package_config.json');
      if (config.existsSync()) {
        final lib = packageLibFromConfig(
          config.uri,
          jsonDecode(config.readAsStringSync()),
          'app_deploy_screenshots',
        );
        if (lib == null) {
          throw StateError('app_deploy_screenshots is not in ${config.path}');
        }
        return Directory.fromUri(lib);
      }
      final parent = dir.parent;
      dir = parent.path == dir.path ? null : parent;
    }
    throw StateError(
      'No .dart_tool/package_config.json above ${Directory.current.path}',
    );
  }

  /// The `lib/` directory of [package] in a parsed `package_config.json`
  /// found at [configUri], or null if it is not listed.
  ///
  /// `rootUri` is written with a trailing slash for the package itself
  /// (`../`) and without one for path dependencies
  /// (`../../../app_deploy_screenshots`). Resolving against the second as-is
  /// replaces its last segment instead of descending into it, so both URIs
  /// are normalised to directories first.
  @visibleForTesting
  static Uri? packageLibFromConfig(
    Uri configUri,
    Object? json,
    String package,
  ) {
    if (json is! Map || json['packages'] is! List) {
      throw FormatException('Unrecognised package_config.json', '$configUri');
    }
    for (final p in (json['packages'] as List).cast<Map>()) {
      if (p['name'] != package) continue;
      String dir(String path) => path.endsWith('/') ? path : '$path/';
      final root = configUri.resolve(dir(p['rootUri'] as String));
      return root.resolve(dir((p['packageUri'] as String?) ?? 'lib/'));
    }
    return null;
  }

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
  }) {
    final platformDevices = [
      DevicePlatform.ios,
      DevicePlatform.android,
    ].expand(Device.byPlatform).toList();

    return byDevices(
      tester,
      name,
      finder: finder,
      customPump: customPump,
      deviceSetup: deviceSetup,
      devices: platformDevices,
      fileNameBuilder:
          fileNameBuilder ??
          (device) =>
              'app_deploy_screenshots/${device.platform.name}/${device.displaySize.label}_${device.name}/$name.png',
      variants: variants,
      order: order,
      statusBar: statusBar,
      annotations: annotations,
      frame: frame,
    );
  }

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
  }) {
    return byDevices(
      tester,
      name,
      devices: devices,
      finder: finder,
      customPump: customPump,
      deviceSetup: deviceSetup,
      fileNameBuilder: (device) =>
          '$root/${device.platform.name}/${device.name}/$name.png',
      variants: variants,
      order: order,
      statusBar: statusBar,
      annotations: annotations,
      frame: frame,
    );
  }

  /// The directory screenshots are written to unless a path says otherwise.
  static const String defaultRoot = 'app_deploy_screenshots';

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
  }) async {
    assert(devices == null || devices.isNotEmpty);
    assert(variants.isNotEmpty);
    assert(order == null || order > 0, 'order starts at 1');
    final defaultDevices = [Device.iphone16Pro, Device.ipadProM4];
    final records = <ScreenshotRecord>[];

    // Images are primed per device inside [byDevice], after its pumps. Priming
    // once up front is not enough: a widget laid out again at a new device
    // size (a list tile, a `ResizeImage` keyed by width) requests a new image
    // that nobody waits for, and the capture shows an empty placeholder.
    for (final device in devices ?? defaultDevices) {
      for (final variant in variants) {
        final context = ScreenshotContext(
          name: name,
          device: variant.applyTo(device),
          variant: variant,
          order: order,
        );
        final path = fileNameBuilder == null
            ? '$defaultRoot/${device.name}.${context.fileStem}.png'
            : _withStem(fileNameBuilder(context.device), context);
        records.add(
          await byDevice(
            tester,
            name,
            customPump: customPump,
            deviceSetup: deviceSetup,
            finder: finder,
            device: device,
            fileName: path,
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

  /// Replaces the file name in [path] with the context's stem, keeping the
  /// directory: `a/b/home.png` becomes `a/b/01_home.dark.png`.
  static String _withStem(String path, ScreenshotContext context) {
    if (context.order == null && context.variant.suffix.isEmpty) return path;
    final slash = path.lastIndexOf('/');
    final dir = path.substring(0, slash + 1);
    var base = path.substring(slash + 1);
    if (base.endsWith('.png')) base = base.substring(0, base.length - 4);
    final prefix = context.order == null
        ? ''
        : '${context.order.toString().padLeft(2, '0')}_';
    final suffix = context.variant.suffix.isEmpty
        ? ''
        : '.${context.variant.suffix}';
    return '$dir$prefix$base$suffix.png';
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
    late ScreenshotRecord record;

    Future<void> body() async {
      final locale = variant.locale;
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
        if (_lastBrightness != context.device.brightness) {
          for (var t = Duration.zero; t < _themeTransition; t += _frame) {
            await tester.pump(_frame);
          }
          _lastBrightness = context.device.brightness;
        }

        final deviceSetupPump = deviceSetup ?? _twoPumps;

        await deviceSetupPump(context.device, tester);

        final pumpAfterPrime = customPump ?? _onlyPumpAndSettle;

        await pumpAfterPrime(tester);

        if (waitForImages) {
          await primeAssets(tester);
          // Decoding completes outside the frame; one more frame paints it.
          await tester.pump();
        }

        record = await _capture(
          tester,
          context,
          fileName: fileName,
          finder: finder,
          statusBar: statusBar,
          annotations: annotations,
          frame: frame?.resolve(context),
        );
      } finally {
        debugDisableShadows = shadowsWereDisabled;
        _markTreeNeedsPaint(tester);
        if (locale != null) tester.platformDispatcher.clearLocalesTestValue();
      }
    }

    await (applyDeviceOverrides
        ? tester.binding.runWithDeviceOverrides(context.device, body: body)
        : body());
    screenshotLog.add(record);
    return record;
  }

  static Future<ScreenshotRecord> _capture(
    WidgetTester tester,
    ScreenshotContext context, {
    required String fileName,
    required Finder? finder,
    required StatusBarOverlay? statusBar,
    required List<ScreenshotAnnotation> annotations,
    required MarketingFrame? frame,
  }) async {
    final device = context.device;
    // Resolve everything that reads the widget tree now, before leaving the
    // fake-async zone.
    final resolved = resolveAnnotations(tester, annotations);
    final element = (finder ?? find.byWidgetPredicate((w) => true))
        .evaluate()
        .first;
    final boundary = _repaintBoundaryOf(element);
    final renderView = tester.binding.renderViews.first;
    final view = tester.view;
    final viewSize = view.physicalSize / view.devicePixelRatio;

    // The part of the view the capture covers, in logical points.
    final Rect captured;
    final Future<ui.Image> imageFuture;
    if (boundary is RenderView) {
      captured = Offset.zero & viewSize;
      imageFuture = captureImage(element);
    } else {
      final box = boundary as RenderBox;
      captured = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      imageFuture = captureImage(element, pixelRatio: view.devicePixelRatio);
    }

    final icons =
        statusBar?.iconBrightness ??
        statusBarIconsFor(
          renderView.debugLayer?.find<SystemUiOverlayStyle>(
            Offset(
              view.physicalSize.width / 2,
              device.safeArea.top * view.devicePixelRatio / 2,
            ),
          ),
          device,
        );

    return (await tester.runAsync(() async {
      final raw = await imageFuture;
      final perLogical = raw.width / captured.width;

      // Status bar and on-screen annotations, drawn in view coordinates.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawImage(raw, Offset.zero, Paint());
      canvas
        ..save()
        ..scale(perLogical)
        ..translate(-captured.left, -captured.top);
      statusBar?.paint(canvas, device, icons: icons);
      paintScreenAnnotations(canvas, viewSize, resolved);
      canvas.restore();
      final hasMagnifiers = resolved.any((r) => r.annotation is MagnifierInset);

      void magnify(
        Canvas c,
        Size out,
        Offset Function(Offset) toOutput,
        double outPerLogical,
      ) => paintMagnifiers(
        c,
        resolved: resolved,
        source: raw,
        sourceRect: captured,
        sourcePerLogical: perLogical,
        toOutput: toOutput,
        outputPerLogical: outPerLogical,
        output: out,
      );

      if (frame == null && hasMagnifiers) {
        magnify(
          canvas,
          Size(raw.width.toDouble(), raw.height.toDouble()),
          (p) => (p - captured.topLeft) * perLogical,
          perLogical,
        );
      }
      final picture = recorder.endRecording();
      final screen = await picture.toImage(raw.width, raw.height);
      picture.dispose();

      var output = screen;
      double? captionCoverage;
      if (frame != null) {
        final framed = await composeFrame(
          frame: frame,
          screen: screen,
          pointWidth: device.size.width,
          screenLogicalWidth: captured.width,
          defaultCornerRadius: device.screenCornerRadius > 0
              ? device.screenCornerRadius
              : 16,
          afterScreen: hasMagnifiers
              ? (c, size, map, scale) => magnify(
                  c,
                  size,
                  (p) => map((p - captured.topLeft) * perLogical),
                  perLogical * scale,
                )
              : null,
        );
        output = framed.image;
        captionCoverage = framed.captionCoverage;
        screen.dispose();
      }

      final bytes = await encodeOpaquePng(output);
      final file = File(fileName);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      final record = ScreenshotRecord(
        path: fileName,
        context: context,
        width: output.width,
        height: output.height,
        framed: frame != null,
        captionCoverage: captionCoverage,
      );
      output.dispose();
      raw.dispose();
      return record;
    }))!;
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
      if (manifest) await writeManifest(root);
      if (contactSheets) await writeContactSheets(root, columns: columns);
    }

    await (tester == null ? write() : tester.runAsync(write));

    final limit = playCaptionCoverageLimit;
    if (limit == null || !manifest) return const [];
    final over = captionCoverageOver(root, limit);
    for (final (path, coverage) in over) {
      debugPrint(
        '⚠️ app_deploy_screenshots: $path caption covers '
        '${(coverage * 100).toStringAsFixed(1)}% of the image '
        '(Google Play guidance: ${(limit * 100).round()}% or less)',
      );
    }
    return over;
  }

  static RenderObject _repaintBoundaryOf(Element element) {
    RenderObject? renderObject = element.renderObject;
    while (renderObject != null && !renderObject.isRepaintBoundary) {
      renderObject = renderObject.parent;
    }
    if (renderObject == null) {
      throw StateError('No RepaintBoundary found in ancestor chain');
    }
    return renderObject;
  }

  /// Render the closest [RepaintBoundary] of the [element] into an image.
  ///
  /// [pixelRatio] is image pixels per logical pixel for a boundary below the
  /// root view. The root view's layer is already in physical pixels.
  ///
  /// See also:
  ///  * [OffsetLayer.toImage] which is the actual method being called.
  static Future<ui.Image> captureImage(
    Element element, {
    double pixelRatio = 1,
  }) {
    assert(element.renderObject != null);

    final renderObject = _repaintBoundaryOf(element);

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

  ///By default, flutter test only uses a single "test" font called Ahem.
  ///
  ///This font is designed to show black spaces for every character and icon. This obviously makes goldens much less valuable.
  ///
  ///To make the goldens more useful, we will automatically load any fonts included in your pubspec.yaml as well as from
  ///packages you depend on.
  ///
  /// [verbose] - If true, prints detailed information about font loading progress
  /// [skipOnError] - If true, continues loading other fonts even if one fails
  static Future<void> loadAppFonts({
    bool verbose = false,
    bool skipOnError = true,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    _verbosePrint('🔤 Loading app fonts for screenshot tests...', verbose);

    try {
      final fontManifest = await rootBundle
          .loadStructuredData<Iterable<dynamic>>(
            'FontManifest.json',
            (string) async => json.decode(string),
          );

      int loadedFonts = 0;
      int failedFonts = 0;

      for (final Map<String, dynamic> font in fontManifest) {
        final fontFamily = _derivedFontFamily(font);
        final fontLoader = FontLoader(fontFamily);

        for (final Map<String, dynamic> fontType in font['fonts']) {
          final asset = fontType['asset'] as String;
          // URL decode the asset path to handle spaces in filenames (e.g., Font Awesome 7)
          final decodedAsset = Uri.decodeComponent(asset);
          _verbosePrint('  Loading font asset: $decodedAsset', verbose);

          try {
            fontLoader.addFont(rootBundle.load(decodedAsset));
          } catch (e) {
            failedFonts++;

            _verbosePrint(
              '  ⚠️ Failed to load font $decodedAsset: $e',
              verbose,
            );

            if (!skipOnError) rethrow;
          }
        }

        await fontLoader.load();
        loadedFonts++;

        _verbosePrint(
          '  ✅ Successfully loaded font family: $fontFamily',
          verbose,
        );
      }

      _verbosePrint(
        '✅ Font loading complete: $loadedFonts loaded, $failedFonts failed',
        verbose,
      );
    } catch (e) {
      _verbosePrint('❌ Font manifest loading failed: $e', verbose);

      if (!skipOnError) rethrow;
    }
  }

  /// A function that waits for all [Image] widgets found in the widget tree to finish decoding.
  ///
  /// Currently this supports images included via Image widgets, or as part of BoxDecorations.
  static Future<void> primeAssets(WidgetTester tester) async {
    final imageElements = find.byType(Image, skipOffstage: false).evaluate();
    final containerElements = find
        .byType(DecoratedBox, skipOffstage: false)
        .evaluate();
    await tester.runAsync(() async {
      for (final imageElement in imageElements) {
        final widget = imageElement.widget;
        if (widget is Image) {
          await precacheImage(widget.image, imageElement);
        }
      }
      for (final container in containerElements) {
        final widget = container.widget as DecoratedBox;
        final decoration = widget.decoration;
        if (decoration is BoxDecoration) {
          if (decoration.image != null) {
            await precacheImage(decoration.image!.image, container);
          }
        }
      }
    });
  }

  /// Sets up common platform channel mocks to prevent test failures
  static void _setupCommonChannelMocks({bool verbose = false}) {
    if (verbose) {
      debugPrint('📱 Setting up platform channel mocks...');
    }

    // Mock sharing intent plugin (common in many apps)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('receive_sharing_intent/messages'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'getInitialMedia':
                return '[]';
              case 'getInitialText':
                return '';
              case 'reset':
                return null;
              default:
                return null;
            }
          },
        );

    // Mock sharing intent event channels
    const codec = StandardMethodCodec();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('receive_sharing_intent/events-media', (
          ByteData? message,
        ) async {
          if (message != null) {
            final methodCall = codec.decodeMethodCall(message);
            if (methodCall.method == 'listen') {
              return codec.encodeSuccessEnvelope('[]');
            } else if (methodCall.method == 'cancel') {
              return codec.encodeSuccessEnvelope(null);
            }
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('receive_sharing_intent/events-text', (
          ByteData? message,
        ) async {
          if (message != null) {
            final methodCall = codec.decodeMethodCall(message);
            if (methodCall.method == 'listen') {
              return codec.encodeSuccessEnvelope('');
            } else if (methodCall.method == 'cancel') {
              return codec.encodeSuccessEnvelope(null);
            }
          }
          return null;
        });

    // Mock shared preferences (common in apps with settings)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'getAll':
                return <String, dynamic>{};
              default:
                return null;
            }
          },
        );

    if (verbose) {
      debugPrint('  ✅ Platform channel mocks configured');
    }
  }

  static Future<void> _onlyPumpAndSettle(WidgetTester tester) =>
      tester.pumpAndSettle();

  /// Room for three chained `kThemeAnimationDuration` (200 ms) animations.
  static const Duration _themeTransition = Duration(milliseconds: 600);
  static const Duration _frame = Duration(milliseconds: 50);

  /// The brightness of the last capture, to detect a theme transition.
  static Brightness? _lastBrightness;

  static void _markTreeNeedsPaint(WidgetTester tester) {
    void visit(RenderObject o) {
      o.markNeedsPaint();
      o.visitChildren(visit);
    }

    for (final view in tester.binding.renderViews) {
      visit(view);
    }
  }

  static Future<void> _twoPumps(Device device, WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  static void _verbosePrint(String message, bool verbose) {
    if (verbose) debugPrint(message);
  }

  /// There is no way to easily load the Roboto or Cupertino fonts.
  /// To make them available in tests, a package needs to include their own copies of them.
  ///
  /// GoldenToolkit supplies Roboto because it is free to use.
  ///
  /// However, when a downstream package includes a font, the font family will be prefixed with
  /// /packages/\<package name\>/\<fontFamily\> in order to disambiguate when multiple packages include
  /// fonts with the same name.
  ///
  /// Ultimately, the font loader will load whatever we tell it, so if we see a font that looks like
  /// a Material or Cupertino font family, let's treat it as the main font family
  static String _derivedFontFamily(Map<String, dynamic> fontDefinition) {
    if (!fontDefinition.containsKey('family')) {
      return '';
    }

    final String fontFamily = fontDefinition['family'];

    if (_overridableFonts.contains(fontFamily)) {
      return fontFamily;
    }

    if (fontFamily.startsWith('packages/')) {
      final fontFamilyName = fontFamily.split('/').last;
      if (_overridableFonts.any((font) => font == fontFamilyName)) {
        return fontFamilyName;
      }
    } else {
      for (final Map<String, dynamic> fontType in fontDefinition['fonts']) {
        final String? asset = fontType['asset'];
        if (asset != null && asset.startsWith('packages')) {
          final packageName = asset.split('/')[1];
          return 'packages/$packageName/$fontFamily';
        }
      }
    }
    return fontFamily;
  }
}

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    //overriding this method to avoid limit of 10KB per asset
    final data = await load(key);
    return utf8.decode(data.buffer.asUint8List());
  }

  @override
  Future<ByteData> load(String key) async => rootBundle.load(key);
}
