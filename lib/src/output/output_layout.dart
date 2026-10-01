import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

import '../../device.dart';
import '../variant.dart';
import 'output_paths.dart';
import 'store_locales.dart';

/// The file a screenshot is written to.
@internal
typedef OutputPath = String Function(Device device, ScreenshotContext context);

/// Picks the store folder for [locale] on [platform]'s store, overriding
/// the built-in mapping. Return null to use the built-in one.
typedef LocaleFolder = String? Function(Locale locale, DevicePlatform platform);

/// Where the store methods write their files.
///
/// ```dart
/// output: OutputLayout.folders(),    // one folder per store slot (default)
/// output: OutputLayout.fastlane(),   // ready for `fastlane deliver` / `supply`
/// ```
@immutable
sealed class OutputLayout {
  const OutputLayout();

  /// `<root>/<platform>/<device>/01_home.dark.fr_FR.png`: one folder per store
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
  ///   and `wearScreenshots` chosen by `Device.effectiveType`. supply has no
  ///   Chromebook folder: write those with [OutputLayout.folders] and
  ///   upload them in the Play Console.
  ///
  /// The locale folder is the tag each store uses for the variant's
  /// locale, which can differ: `Locale('ja', 'JP')` is `ja` on the App
  /// Store and `ja-JP` on Google Play, Hebrew `he` and `iw-IL`, simplified
  /// Chinese `zh-Hans` and `zh-CN`. Screenshots whose variant has no locale
  /// go in [defaultLocale]'s folder. It only names the folder: those
  /// screenshots still render in the test's locale (en-US), so for an app
  /// in another language give the variants its locale, e.g.
  /// `variants: [ScreenshotVariant(locale: Locale('de', 'DE'))]`.
  /// [localeFolder] overrides the mapping, for a language a store added
  /// after this package's list (fastlane 2.240) or a folder of your
  /// choosing. Layouts compare equal only with the same [localeFolder]
  /// function, so pass a named function rather than a new closure if that
  /// matters.
  ///
  /// Both tools upload every file in a folder, in file name order (which
  /// the order prefix sets), replacing the store's current screenshots. So
  /// before anything is captured, it is an error for:
  ///
  /// * a locale to have no folder on a store it is written for, or to be
  ///   too vague to place (`Locale('en')`: US, UK, …?);
  /// * two variants to share a folder (light and dark of `fr-FR`): both
  ///   would upload. Write the other brightness to another root;
  /// * two devices to share a slot (two Play phones, or two iPhones of one
  ///   pixel size): one would replace the other.
  const factory OutputLayout.fastlane({
    String root,
    Locale defaultLocale,
    LocaleFolder? localeFolder,
  }) = _Fastlane;

  /// The folder everything is written under. Pass the same layout to
  /// `writeReport`.
  String get root;

  /// The path for each screenshot of [variants] on [devices], after
  /// checking this layout can hold them all; throws `ArgumentError` if it
  /// can't. Not part of the public API.
  @internal
  OutputPath pathsFor(List<Device> devices, List<ScreenshotVariant> variants);
}

final class _Folders extends OutputLayout {
  const _Folders([this.root = OutputPaths.defaultRoot]);

  @override
  final String root;

  @override
  OutputPath pathsFor(List<Device> devices, List<ScreenshotVariant> variants) =>
      (device, context) => OutputPaths.store(root, device, context);

  @override
  bool operator ==(Object other) => other is _Folders && other.root == root;

  @override
  int get hashCode => root.hashCode;
}

final class _Fastlane extends OutputLayout {
  const _Fastlane({
    this.root = 'fastlane',
    this.defaultLocale = const Locale('en', 'US'),
    this.localeFolder,
  });

  @override
  final String root;

  final Locale defaultLocale;
  final LocaleFolder? localeFolder;

  @override
  OutputPath pathsFor(List<Device> devices, List<ScreenshotVariant> variants) {
    for (final platform in {for (final d in devices) d.platform}) {
      _oneEach(
        'variants',
        variants,
        (v) => '${_folder(v.locale ?? defaultLocale, platform)} folder',
        (v) => '$v',
        'fastlane uploads every file there as another screenshot. Use one '
            'variant per locale, and write the others (dark mode, say) to '
            'OutputLayout.folders() or another root.',
      );
    }
    _oneEach(
      'devices',
      devices,
      (d) => switch (d.platform) {
        DevicePlatform.ios =>
          'App Store slot for ${d.pixelSize.width.round()} × '
              '${d.pixelSize.height.round()} px',
        DevicePlatform.android => '${supplyFolder(d)} folder',
      },
      (d) => d.name,
      'one would replace or join the other in that upload slot. Write the '
          'others with OutputLayout.folders().',
    );
    return _path;
  }

  /// Throws if two of [items] share a [slot].
  static void _oneEach<T>(
    String what,
    List<T> items,
    String Function(T item) slot,
    String Function(T item) describe,
    String why,
  ) {
    final bySlot = <String, List<T>>{};
    for (final item in items) {
      (bySlot[slot(item)] ??= []).add(item);
    }
    for (final MapEntry(key: name, value: shared) in bySlot.entries) {
      if (shared.length > 1) {
        throw ArgumentError(
          'With OutputLayout.fastlane(), the $what '
          '${shared.map(describe).join(' and ')} would all go to the $name, '
          'and $why',
        );
      }
    }
  }

  String _path(Device device, ScreenshotContext context) {
    final locale = _folder(
      context.variant.locale ?? defaultLocale,
      device.platform,
    );
    // The locale becomes the folder, so only the brightness stays in the
    // name; the order prefix leads, because both tools sort by name.
    final brightness = context.variant.brightness;
    final stem =
        '${context.orderPrefix}${context.name}'
        '${brightness == null ? '' : '.${brightness.name}'}';
    return switch (device.platform) {
      DevicePlatform.ios =>
        '$root/screenshots/$locale/${stem}_${device.name}.png',
      DevicePlatform.android =>
        '$root/metadata/android/$locale/images/'
            '${supplyFolder(device)}/$stem.png',
    };
  }

  /// The locale folder for [locale] on [platform]'s store.
  String _folder(Locale locale, DevicePlatform platform) {
    final custom = localeFolder?.call(locale, platform);
    assert(
      custom == null || (custom.isNotEmpty && !custom.contains('/')),
      'localeFolder returned "$custom" for $locale: a folder name, please.',
    );
    final tag = custom ?? StoreLocales.tagFor(locale, platform);
    if (tag != null) return tag;
    final options = StoreLocales.suggestionsFor(locale, platform);
    throw ArgumentError(
      '${StoreLocales.storeName(platform)} has no screenshot folder for '
      '${locale.toLanguageTag()}. '
      '${options.isEmpty ? 'It does not list that language' : 'For that language it has ${options.join(', ')}'}. '
      'Use the Locale for one of those; or, if the store lists it, '
      'name the folder with OutputLayout.fastlane(localeFolder: ...); or, '
      'for a language only one store has, give that store its own listing '
      '(devices: Device.playStore).',
    );
  }

  /// supply's screenshot folder for [device].
  @visibleForTesting
  static String supplyFolder(Device device) => switch (device.effectiveType) {
    DeviceType.phone => 'phoneScreenshots',
    DeviceType.tablet =>
      device.size.shortestSide >= 720
          ? 'tenInchScreenshots'
          : 'sevenInchScreenshots',
    DeviceType.tv => 'tvScreenshots',
    DeviceType.wear => 'wearScreenshots',
    DeviceType.chromebook => throw ArgumentError(
      'fastlane supply has no Chromebook screenshot folder, so '
      '${device.name} can\'t be written with OutputLayout.fastlane(). '
      'Capture it with OutputLayout.folders() and upload it in the Play '
      'Console.',
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is _Fastlane &&
      other.root == root &&
      other.defaultLocale == defaultLocale &&
      other.localeFolder == localeFolder;

  @override
  int get hashCode => Object.hash(root, defaultLocale, localeFolder);
}
