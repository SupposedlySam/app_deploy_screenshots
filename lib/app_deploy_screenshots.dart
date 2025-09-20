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

export 'device.dart';
export 'extensions.dart';

///CustomPump is a function that lets you do custom pumping before golden evaluation.
///Sometimes, you want to do a golden test for different stages of animations, so its crucial to have a precise control over pumps and durations
typedef CustomPump = Future<void> Function(WidgetTester);

/// Function definition for allowing for device or test setup to occur for each device configuration under test
typedef DeviceSetup = Future<void> Function(Device device, WidgetTester tester);

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
  static Future<void> initialize({
    bool loadFonts = true,
    bool verbose = false,
    bool mockPlatformChannels = true,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    _verbosePrint('🚀 Initializing screenshot test environment...', verbose);

    // Load fonts for better text rendering
    if (loadFonts) {
      await loadAppFonts(verbose: verbose, skipOnError: true);
    }

    // Mock common platform channels that might interfere with tests
    if (mockPlatformChannels) {
      _setupCommonChannelMocks(verbose: verbose);
    }

    _verbosePrint('✅ Screenshot test environment ready!', verbose);
  }

  /// Creates all ios and android screnshots based on app store guidelines
  ///
  /// iPhone: Adding accurate screenshots of your app on the newest devices can help you represent the app's user experience. Keep in mind that we'll use these screenshots for all display sizes and localizations. Screenshots are only required for iOS apps, and only the first 3 will be used on the app installation sheets.
  ///   6.9": Drag up to 3 app previews and 10 screenshots here for iPhone 6.7" or 6.9" Displays. (1320 × 2868px, 2868 × 1320px, 1290 × 2796px or 2796 × 1290px)
  ///   6.5": Drag up to 3 app previews and 10 screenshots here. (1242 × 2688px, 2688 × 1242px, 1284 × 2778px or 2778 × 1284px)
  ///   iPad-13: Drag up to 3 app previews and 10 screenshots here for iPad 12.9" or 13" Displays. (2064 × 2752px, 2752 × 2064px, 2048 × 2732px or 2732 × 2048px)
  /// android:
  ///   phone: Upload 2-8 phone screenshots. Screenshots must be PNG or JPEG, up to 8 MB each, 16:9 or 9:16 aspect ratio, with each side between 320 px and 3,840 px
  ///   tablet-7: Upload up to eight 7-inch tablet screenshots. Screenshots must be PNG or JPEG, up to 8 MB each, 16:9 or 9:16 aspect ratio, with each side between 320 px and 3,840 px
  ///   tablet-10: Upload up to eight 10-inch tablet screenshots. Screenshots must be PNG or JPEG, up to 8 MB each, 16:9 or 9:16 aspect ratio, with each side between 1,080 px and 7,680 px
  ///   chromebook: Upload 4-8 screenshots. Screenshots must be PNG or JPEG, up to 8 MB each, 16:9 or 9:16 aspect ratio, with each side between 1,080 px and 7,680 px
  ///
  /// See also: [byDevice], [byDevices]
  static Future<void> byPlatform(
    WidgetTester tester,
    String name, {
    Finder? finder,
    CustomPump? customPump,
    String Function(Device device)? fileNameBuilder,
  }) async {
    final platformDevices = [
      DevicePlatform.ios,
      DevicePlatform.android,
    ].expand(Device.byPlatform).toList();

    return byDevices(
      tester,
      name,
      devices: platformDevices,
      fileNameBuilder: (device) =>
          'app_deploy_screenshots/${device.platform.name}/${device.displaySize.label}_${device.name}/$name.png',
    );
  }

  /// Generates screenshots for a list of devices
  ///
  /// [name] is the name of the screenshot
  /// [finder] is an optional finder to use for the screenshot
  /// [customPump] is an optional pump to use for the screenshot
  /// [deviceSetup] is an optional function to use for the screenshot
  /// [devices] is a list of devices to use for the screenshot
  /// [fileNameBuilder] is an optional function to use for the screenshot
  ///
  /// see also: [byPlatform], [byDevice]
  static Future<void> byDevices(
    WidgetTester tester,
    String name, {
    Finder? finder,
    CustomPump? customPump,
    DeviceSetup? deviceSetup,
    List<Device>? devices,
    String Function(Device device)? fileNameBuilder,
  }) async {
    assert(devices == null || devices.isNotEmpty);
    final deviceSetupPump = deviceSetup ?? _twoPumps;
    final defaultDevices = [Device.iphone16Pro, Device.ipadProM4];
    await primeAssets(tester);

    for (final device in devices ?? defaultDevices) {
      await tester.binding.runWithDeviceOverrides(
        device,
        body: () async {
          await deviceSetupPump(device, tester);
          await byDevice(
            tester,
            name,
            customPump: customPump,
            finder: finder,
            device: device,
            fileName:
                fileNameBuilder?.call(device) ??
                'app_deploy_screenshots/${device.name}.$name.png',
            waitForImages: false,
          );
        },
      );
    }
  }

  /// Captures a screenshot of the widget and saves it to a file
  ///
  /// See also: [byPlatform], [byDevices]
  static Future<void> byDevice(
    WidgetTester tester,
    String name, {
    required Device device,
    required String fileName,
    Finder? finder,
    CustomPump? customPump,
    bool waitForImages = true,
  }) async {
    assert(
      !name.endsWith('.png'),
      'Screenshot names should not include file type',
    );

    final pumpAfterPrime = customPump ?? _onlyPumpAndSettle;

    await pumpAfterPrime(tester);

    if (waitForImages) await primeAssets(tester);

    // Capture the image using WidgetTester's standard approach
    final actualFinder = finder ?? find.byWidgetPredicate((w) => true).first;

    // Capture the image
    final imageFuture = captureImage(actualFinder.evaluate().first);

    // Save the image to a file
    final file = File(fileName);
    await tester.runAsync(() async {
      final ui.Image image = await imageFuture;
      try {
        final ByteData? bytes = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (bytes == null) {
          return 'could not encode screenshot.';
        } else {
          await file.create(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  /// Render the closest [RepaintBoundary] of the [element] into an image.
  ///
  /// See also:
  ///  * [OffsetLayer.toImage] which is the actual method being called.
  static Future<ui.Image> captureImage(Element element) {
    assert(element.renderObject != null);

    RenderObject? renderObject = element.renderObject!;

    // Find RepaintBoundary with safety check
    while (renderObject != null && !renderObject.isRepaintBoundary) {
      renderObject = renderObject.parent;
    }

    if (renderObject == null) {
      throw StateError('No RepaintBoundary found in ancestor chain');
    }

    assert(!renderObject.debugNeedsPaint);

    final layer = renderObject.debugLayer;
    if (layer is! OffsetLayer) {
      throw StateError('Expected OffsetLayer but got ${layer.runtimeType}');
    }

    return layer.toImage(renderObject.paintBounds);
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
