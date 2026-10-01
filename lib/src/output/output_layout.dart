import 'package:flutter/foundation.dart';

import '../../device.dart';
import '../variant.dart';
import 'output_paths.dart';

/// Where the store methods write their files.
///
/// ```dart
/// output: OutputLayout.folders(),    // one folder per store slot (default)
/// output: OutputLayout.fastlane(),   // ready for `fastlane deliver` / `supply`
/// ```
@immutable
sealed class OutputLayout {
  const OutputLayout();

  /// `<root>/<platform>/<device>/01_home.dark.fr.png`: one folder per store
  /// upload slot, every variant side by side.
  const factory OutputLayout.folders([String root]) = _Folders;

  /// The folders fastlane uploads from, so `fastlane deliver` (App Store)
  /// and `fastlane supply` (Google Play) pick the screenshots up as they
  /// are:
  ///
  /// * iOS: `<root>/screenshots/<locale>/01_home_app_store_iphone_6_9.png`.
  ///   deliver tells devices apart by pixel size.
  /// * Android:
  ///   `<root>/metadata/android/<locale>/images/phoneScreenshots/01_home.png`,
  ///   with `sevenInchScreenshots`, `tenInchScreenshots` and
  ///   `wearScreenshots` chosen from the device's size.
  ///
  /// The locale folder is the variant's locale as a language tag, or
  /// [defaultLocale] for screenshots without one. Use full tags the stores
  /// know, such as `Locale('fr', 'FR')` for `fr-FR`. Both tools upload in
  /// file name order, which the order prefix sets. Each folder replaces the
  /// store's current screenshots, so give each upload one brightness: a
  /// `.dark` variant would be uploaded as an extra screenshot.
  const factory OutputLayout.fastlane({String root, String defaultLocale}) =
      _Fastlane;

  /// The folder everything is written under. Pass the same layout to
  /// `writeReport`.
  String get root;

  /// The file for [context] on [device]. Not part of the public API.
  @internal
  String pathFor(Device device, ScreenshotContext context);
}

final class _Folders extends OutputLayout {
  const _Folders([this.root = OutputPaths.defaultRoot]);

  @override
  final String root;

  @override
  String pathFor(Device device, ScreenshotContext context) =>
      OutputPaths.store(root, device, context);

  @override
  bool operator ==(Object other) => other is _Folders && other.root == root;

  @override
  int get hashCode => root.hashCode;
}

final class _Fastlane extends OutputLayout {
  const _Fastlane({this.root = 'fastlane', this.defaultLocale = 'en-US'});

  @override
  final String root;

  /// Locale folder for screenshots whose variant sets none.
  final String defaultLocale;

  @override
  String pathFor(Device device, ScreenshotContext context) {
    final locale = context.variant.locale?.toLanguageTag() ?? defaultLocale;
    // The locale becomes the folder, so only the brightness stays in the
    // name; the order prefix leads, because both tools sort by name.
    final brightness = context.variant.brightness;
    final stem =
        '${context.orderPrefix}${context.name}'
        '${brightness == null ? '' : '.${brightness.name}'}';
    if (device.platform == DevicePlatform.ios) {
      return '$root/screenshots/$locale/${stem}_${device.name}.png';
    }
    return '$root/metadata/android/$locale/images/'
        '${androidFolder(device)}/$stem.png';
  }

  /// supply's folder for [device], from its size: square and small is a
  /// watch, 600 dp or more across is a tablet (720 dp or more a 10-inch).
  @visibleForTesting
  static String androidFolder(Device device) {
    final shortest = device.size.shortestSide;
    if (device.size.width == device.size.height && shortest < 400) {
      return 'wearScreenshots';
    }
    if (shortest >= 720) return 'tenInchScreenshots';
    if (shortest >= 600) return 'sevenInchScreenshots';
    return 'phoneScreenshots';
  }

  @override
  bool operator ==(Object other) =>
      other is _Fastlane &&
      other.root == root &&
      other.defaultLocale == defaultLocale;

  @override
  int get hashCode => Object.hash(root, defaultLocale);
}
