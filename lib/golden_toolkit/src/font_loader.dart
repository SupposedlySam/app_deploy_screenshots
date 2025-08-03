import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

///By default, flutter test only uses a single "test" font called Ahem.
///
///This font is designed to show black spaces for every character and icon. This obviously makes goldens much less valuable.
///
///To make the goldens more useful, we will automatically load any fonts included in your pubspec.yaml as well as from
///packages you depend on.
///
/// [verbose] - If true, prints detailed information about font loading progress
/// [skipOnError] - If true, continues loading other fonts even if one fails
Future<void> loadAppFonts(
    {bool verbose = false, bool skipOnError = true}) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (verbose) {
    debugPrint('🔤 Loading app fonts for screenshot tests...');
  }

  try {
    final fontManifest = await rootBundle.loadStructuredData<Iterable<dynamic>>(
      'FontManifest.json',
      (string) async => json.decode(string),
    );

    int loadedFonts = 0;
    int failedFonts = 0;

    for (final Map<String, dynamic> font in fontManifest) {
      try {
        final fontFamily = derivedFontFamily(font);
        final fontLoader = FontLoader(fontFamily);

        for (final Map<String, dynamic> fontType in font['fonts']) {
          final asset = fontType['asset'] as String;
          if (verbose) {
            debugPrint('  Loading font asset: $asset');
          }
          fontLoader.addFont(rootBundle.load(asset));
        }

        await fontLoader.load();
        loadedFonts++;

        if (verbose) {
          debugPrint('  ✅ Successfully loaded font family: $fontFamily');
        }
      } catch (e) {
        failedFonts++;
        if (verbose) {
          debugPrint('  ⚠️ Failed to load font ${font['family']}: $e');
        }
        if (!skipOnError) {
          rethrow;
        }
      }
    }

    if (verbose) {
      debugPrint(
          '✅ Font loading complete: $loadedFonts loaded, $failedFonts failed');
    }
  } catch (e) {
    if (verbose) {
      debugPrint('❌ Font manifest loading failed: $e');
    }
    if (!skipOnError) {
      rethrow;
    }
  }
}

/// There is no way to easily load the Roboto or Cupertino fonts.
/// To make them available in tests, a package needs to include their own copies of them.
///
/// GoldenToolkit supplies Roboto because it is free to use.
///
/// However, when a downstream package includes a font, the font family will be prefixed with
/// /packages/<package name>/<fontFamily> in order to disambiguate when multiple packages include
/// fonts with the same name.
///
/// Ultimately, the font loader will load whatever we tell it, so if we see a font that looks like
/// a Material or Cupertino font family, let's treat it as the main font family
@visibleForTesting
String derivedFontFamily(Map<String, dynamic> fontDefinition) {
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

const List<String> _overridableFonts = [
  'Roboto',
  '.SF UI Display',
  '.SF UI Text',
  '.SF Pro Text',
  '.SF Pro Display',
];
