import 'dart:ui' show Brightness, Locale, Size, TextDirection;

import 'package:flutter/foundation.dart';

import '../device.dart';

/// One rendering of a screen: a brightness, a locale, or both.
///
/// Pass several to `byDevices(variants: ...)` to capture every combination in
/// one call. Each variant adds a suffix to the file name, e.g.
/// `01_home.dark.fr.png`.
///
/// The package applies the variant through the platform, as a device would:
/// `platformBrightness` and `locales`. An app that follows the system theme
/// (`ThemeMode.system`) and the system locale needs nothing else. An app that
/// keeps these in its own state can read them in `deviceSetup` from
/// `tester.platformDispatcher`, or from `Device.brightness`.
@immutable
final class ScreenshotVariant {
  const ScreenshotVariant({this.brightness, this.locale, String? suffix})
    : _suffix = suffix;

  /// The device as configured, with no file name suffix.
  static const ScreenshotVariant none = ScreenshotVariant();

  /// Light mode, with the suffix `.light`.
  static const ScreenshotVariant light = ScreenshotVariant(
    brightness: Brightness.light,
  );

  /// Dark mode, with the suffix `.dark`.
  static const ScreenshotVariant dark = ScreenshotVariant(
    brightness: Brightness.dark,
  );

  /// Every combination of [brightnesses] and [locales], brightness first.
  ///
  /// An empty list leaves that axis unset, so
  /// `matrix(locales: [en, fr])` renders both locales in the device's
  /// configured brightness.
  static List<ScreenshotVariant> matrix({
    List<Brightness> brightnesses = const [],
    List<Locale> locales = const [],
  }) {
    final bs = brightnesses.isEmpty ? const <Brightness?>[null] : brightnesses;
    final ls = locales.isEmpty ? const <Locale?>[null] : locales;
    return [
      for (final b in bs)
        for (final l in ls) ScreenshotVariant(brightness: b, locale: l),
    ];
  }

  /// Platform brightness to apply, or null to keep `Device.brightness`.
  final Brightness? brightness;

  /// Locale to apply as the platform's only locale, or null to keep the
  /// test default.
  final Locale? locale;

  final String? _suffix;

  /// The file name suffix, without a leading dot: `dark`, `fr_CA`,
  /// `dark.fr_CA`, or empty for [none].
  String get suffix =>
      _suffix ??
      [
        if (brightness != null) brightness!.name,
        if (locale != null) locale!.toLanguageTag().replaceAll('-', '_'),
      ].join('.');

  /// [device] with this variant's brightness applied.
  Device applyTo(Device device) =>
      brightness == null ? device : device.copyWith(brightness: brightness);

  @override
  bool operator ==(Object other) =>
      other is ScreenshotVariant &&
      other.brightness == brightness &&
      other.locale == locale &&
      other.suffix == suffix;

  @override
  int get hashCode => Object.hash(brightness, locale, suffix);

  @override
  String toString() => 'ScreenshotVariant(${suffix.isEmpty ? 'none' : suffix})';
}

/// What a screenshot's image was made from.
enum ScreenshotSource {
  /// A capture of the running app.
  app,

  /// A widget rendered on its own, such as a hero slide.
  widget,

  /// A frame with no device: background, caption and decorations.
  poster,
}

/// What is being captured. Passed to every builder, so captions, frames and
/// backgrounds can change per device, locale and brightness.
@immutable
final class ScreenshotContext {
  const ScreenshotContext({
    required this.name,
    required this.device,
    this.variant = ScreenshotVariant.none,
    this.order,
    this.canvasSize,
    this.source = ScreenshotSource.app,
  });

  /// The output size in pixels, when known before rendering (widget slides
  /// and posters).
  final Size? canvasSize;

  /// A copy with the given fields replaced.
  ScreenshotContext copyWith({
    String? name,
    Device? device,
    ScreenshotVariant? variant,
    int? order,
    Size? canvasSize,
    ScreenshotSource? source,
  }) => ScreenshotContext(
    name: name ?? this.name,
    device: device ?? this.device,
    variant: variant ?? this.variant,
    order: order ?? this.order,
    canvasSize: canvasSize ?? this.canvasSize,
    source: source ?? this.source,
  );

  /// What the slide is made from.
  final ScreenshotSource source;

  /// The screenshot name passed to `byDevice` / `byDevices`.
  final String name;

  /// The device, with the variant's brightness already applied.
  final Device device;

  final ScreenshotVariant variant;

  /// Position in the store listing (1-based), if one was given.
  final int? order;

  /// The locale being rendered: the variant's, else `en_US`, which is the
  /// Flutter test default.
  Locale get locale => variant.locale ?? const Locale('en', 'US');

  /// The brightness being rendered.
  Brightness get brightness => device.brightness;

  /// The direction [locale] is written in.
  TextDirection get textDirection => directionOf(locale);

  /// The direction [locale] is written in: right to left for Arabic,
  /// Hebrew, Persian, Urdu, Pashto, Yiddish, Sorani Kurdish, Dhivehi and
  /// Sindhi. Not part of the public API.
  @internal
  static TextDirection directionOf(Locale locale) =>
      const {
        'ar', 'he', 'fa', 'ur', 'ps', 'yi', 'ckb', 'dv', 'sd', //
      }.contains(locale.languageCode)
      ? TextDirection.rtl
      : TextDirection.ltr;

  /// `01_` for order 1, or empty without an order.
  String get orderPrefix =>
      order == null ? '' : '${order.toString().padLeft(2, '0')}_';

  /// `.dark.fr` for that variant, or empty for [ScreenshotVariant.none].
  String get variantSuffix =>
      variant.suffix.isEmpty ? '' : '.${variant.suffix}';

  /// The file stem: order prefix, name and variant suffix, e.g.
  /// `01_home.dark`.
  String get fileStem => '$orderPrefix$name$variantSuffix';
}
