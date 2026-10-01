import 'package:flutter/foundation.dart';

import '../../device.dart';
import '../variant.dart';
import 'output_paths.dart';
import 'store_locales.dart';

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
  ///   with `sevenInchScreenshots`, `tenInchScreenshots`, `tvScreenshots`
  ///   and `wearScreenshots` chosen by the device's `Device.type` (or its
  ///   size, when it has none). supply has no Chromebook folder, so a
  ///   Chromebook device is an error here: write those with
  ///   [OutputLayout.folders] and upload them by hand.
  ///
  /// The locale folder is the tag each store uses for the variant's
  /// locale, which can differ: `Locale('ja', 'JP')` is `ja` on the App
  /// Store and `ja-JP` on Google Play, Hebrew `he` and `iw-IL`, simplified
  /// Chinese `zh-Hans` and `zh-CN`. A locale a store has no folder for, or
  /// one too vague to place (`Locale('en')`: US, UK, …?), is an error
  /// before anything is captured. Screenshots without a locale go in
  /// [defaultLocale]. Both tools upload in file name order, which the order
  /// prefix sets.
  ///
  /// Each folder replaces the store's current screenshots, so it is an error
  /// for two variants to share a locale (light and dark of `fr-FR`, say):
  /// both would upload. Write the other brightness to another root.
  const factory OutputLayout.fastlane({String root, String defaultLocale}) =
      _Fastlane;

  /// The folder everything is written under. Pass the same layout to
  /// `writeReport`.
  String get root;

  /// The file for [context] on [device]. Not part of the public API.
  @internal
  String pathFor(Device device, ScreenshotContext context);

  /// Throws if this layout can't hold [variants] on [devices], before
  /// anything is captured. Not part of the public API.
  @internal
  void check(List<Device> devices, List<ScreenshotVariant> variants) {}
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
    final locale = _folder(context.variant, device.platform);
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

  @override
  void check(List<Device> devices, List<ScreenshotVariant> variants) {
    for (final device in devices) {
      if (device.platform == DevicePlatform.android &&
          device.type == DeviceType.chromebook) {
        throw ArgumentError(
          'fastlane supply has no Chromebook screenshot folder, so '
          '${device.name} can\'t be written with OutputLayout.fastlane(). '
          'Capture it with OutputLayout.folders() and upload it in the Play '
          'Console.',
        );
      }
    }
    for (final platform in {for (final d in devices) d.platform}) {
      final byFolder = <String, List<ScreenshotVariant>>{};
      for (final v in variants) {
        (byFolder[_folder(v, platform)] ??= []).add(v);
      }
      for (final MapEntry(key: folder, value: shared) in byFolder.entries) {
        if (shared.length > 1) {
          throw ArgumentError(
            'With OutputLayout.fastlane(), $shared would all be written to '
            'the $folder folder, and fastlane uploads every file there as '
            'another screenshot. Use one variant per locale, and write the '
            'others (dark mode, say) to OutputLayout.folders() or another '
            'root.',
          );
        }
      }
    }
  }

  /// The locale folder for [variant] on [platform]'s store.
  String _folder(ScreenshotVariant variant, DevicePlatform platform) {
    final locale = variant.locale;
    if (locale == null) return defaultLocale;
    final tag = StoreLocales.tagFor(locale, platform);
    if (tag != null) return tag;
    final store = platform == DevicePlatform.ios
        ? 'The App Store'
        : 'Google Play';
    final options = StoreLocales.suggestionsFor(locale, platform);
    throw ArgumentError(
      '$store has no screenshot folder for ${locale.toLanguageTag()}. '
      '${options.isEmpty ? 'It does not list that language.' : 'For that language it has ${options.join(', ')}: use the Locale for one of those.'}',
    );
  }

  /// supply's folder for [device]: from its `Device.type`, or, without
  /// one, its size: square and small is a watch, 600 dp or more across a
  /// tablet (720 dp or more a 10-inch).
  @visibleForTesting
  static String androidFolder(Device device) {
    final shortest = device.size.shortestSide;
    final type =
        device.type ??
        switch (shortest) {
          _ when device.size.width == device.size.height && shortest < 400 =>
            DeviceType.wear,
          >= 600 => DeviceType.tablet,
          _ => DeviceType.phone,
        };
    return switch (type) {
      DeviceType.phone => 'phoneScreenshots',
      DeviceType.tablet =>
        shortest >= 720 ? 'tenInchScreenshots' : 'sevenInchScreenshots',
      DeviceType.tv => 'tvScreenshots',
      DeviceType.wear => 'wearScreenshots',
      DeviceType.chromebook => throw ArgumentError(
        'fastlane supply has no Chromebook screenshot folder.',
      ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is _Fastlane &&
      other.root == root &&
      other.defaultLocale == defaultLocale;

  @override
  int get hashCode => Object.hash(root, defaultLocale);
}
