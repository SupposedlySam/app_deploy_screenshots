import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads fonts so text renders in real typefaces instead of the test font's
/// black boxes: the app's fonts from `FontManifest.json`, and this package's
/// bundled emoji font.
abstract final class FontSetup {
  static const List<String> _overridableFonts = [
    'Roboto',
    'GoogleSans',
    'GoogleSansDisplay',
    '.SF UI Display',
    '.SF UI Text',
    '.SF Pro Text',
    '.SF Pro Display',
  ];

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
  static Future<void> loadEmojiFont() =>
      _loadBundled('NotoEmoji.ttf', emojiFontFamily);

  /// Font family the package draws its own text in (captions, the status
  /// bar clock, callouts): Roboto as a variable font, so every weight is a
  /// real weight. The package's static Roboto has only the regular weight,
  /// and the test renderer only fakes bold, faintly.
  static const String textFontFamily = 'AppDeployScreenshotsRoboto';

  /// Loads [textFontFamily]. Read from the package's `lib/` like the emoji
  /// font, so it is never bundled into apps.
  static Future<void> loadTextFont() =>
      _loadBundled('Roboto-Variable.ttf', textFontFamily);

  static Future<void> _loadBundled(String file, String family) async {
    final lib = _packageLibDirectory();
    final bytes = await File('${lib.path}/src/fonts/$file').readAsBytes();
    final loader = FontLoader(family)
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

  static void _verbosePrint(String message, bool verbose) {
    if (verbose) debugPrint(message);
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
