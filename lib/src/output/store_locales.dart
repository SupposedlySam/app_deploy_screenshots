import 'dart:ui' show Locale;

import '../../device.dart';

/// The language folders fastlane accepts, and how a Flutter [Locale] maps
/// onto them.
///
/// The App Store and Google Play name the same language differently
/// (Japanese is `ja` on one and `ja-JP` on the other, Hebrew `he` and
/// `iw-IL`), and both tools reject a folder they don't know, at upload.
/// Mapping here lets one `Locale('ja', 'JP')` land in the right folder on
/// both, and an unknown one fail before anything is captured.
abstract final class StoreLocales {
  /// deliver's `FastlaneCore::Languages::ALL_LANGUAGES`.
  static const appStore = {
    'ar-SA', 'bn-BD', 'ca', 'cs', 'da', 'de-DE', 'el', 'en-AU', 'en-CA', //
    'en-GB', 'en-US', 'es-ES', 'es-MX', 'fi', 'fr-CA', 'fr-FR', 'gu-IN',
    'he', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'kn-IN', 'ko', 'ml-IN',
    'mr-IN', 'ms', 'nl-NL', 'no', 'or-IN', 'pa-IN', 'pl', 'pt-BR', 'pt-PT',
    'ro', 'ru', 'sk', 'sl-SI', 'sv', 'ta-IN', 'te-IN', 'th', 'tr', 'uk',
    'ur-PK', 'vi', 'zh-Hans', 'zh-Hant',
  };

  /// supply's `Supply::Languages::ALL_LANGUAGES`, with `-` for `_`: the
  /// Play Console's listing languages.
  static const googlePlay = {
    'af', 'am', 'ar', 'az-AZ', 'be', 'bg', 'bn-BD', 'ca', 'cs-CZ', //
    'da-DK', 'de-DE', 'el-GR', 'en-AU', 'en-CA', 'en-GB', 'en-IN', 'en-SG',
    'en-US', 'en-ZA', 'es-419', 'es-ES', 'es-US', 'et', 'eu-ES', 'fa',
    'fi-FI', 'fil', 'fr-CA', 'fr-FR', 'gl-ES', 'hi-IN', 'hr', 'hu-HU',
    'hy-AM', 'id', 'is-IS', 'it-IT', 'iw-IL', 'ja-JP', 'ka-GE', 'km-KH',
    'kn-IN', 'ko-KR', 'ky-KG', 'lo-LA', 'lt', 'lv', 'mk-MK', 'ml-IN',
    'mn-MN', 'mr-IN', 'ms', 'ms-MY', 'my-MM', 'ne-NP', 'nl-NL', 'no-NO',
    'pl-PL', 'pt-BR', 'pt-PT', 'rm', 'ro', 'ru-RU', 'si-LK', 'sk', 'sl',
    'sr', 'sv-SE', 'sw', 'ta-IN', 'te-IN', 'th', 'tr-TR', 'uk', 'vi',
    'zh-CN', 'zh-HK', 'zh-TW', 'zu',
  };

  /// The folder [platform]'s store uses for [locale], or null if it has
  /// none (or several equally likely, such as `en` on Play).
  static String? tagFor(Locale locale, DevicePlatform platform) {
    final known = platform == DevicePlatform.ios ? appStore : googlePlay;
    final language = switch (locale.languageCode) {
      'iw' => 'he',
      'nb' || 'nn' => 'no',
      'tl' => 'fil',
      final code => code,
    };
    final region = locale.countryCode;

    if (language == 'zh') return _chinese(locale, platform);
    final candidates = [
      locale.toLanguageTag(),
      if (region != null) '$language-$region',
      language,
      // Play's name for Hebrew.
      if (language == 'he') 'iw-${region ?? 'IL'}',
    ];
    for (final tag in candidates) {
      if (known.contains(tag)) return tag;
    }
    // A bare language the store only knows with a region: fine when there
    // is just one (ja → ja-JP), ambiguous when there are several (en).
    if (region == null) {
      final regional = known.where((t) => t.startsWith('$language-'));
      if (regional.length == 1) return regional.single;
    }
    return null;
  }

  static String? _chinese(Locale locale, DevicePlatform platform) {
    final traditional = switch ((locale.scriptCode, locale.countryCode)) {
      ('Hant', _) || (null, 'TW' || 'HK' || 'MO') => true,
      ('Hans', _) || (null, 'CN' || 'SG') => false,
      _ => null,
    };
    if (traditional == null) return null;
    if (platform == DevicePlatform.ios) {
      return traditional ? 'zh-Hant' : 'zh-Hans';
    }
    if (!traditional) return 'zh-CN';
    return locale.countryCode == 'HK' ? 'zh-HK' : 'zh-TW';
  }

  /// The tags [platform]'s store knows for [locale]'s language, for an
  /// error message.
  static List<String> suggestionsFor(Locale locale, DevicePlatform platform) {
    final known = platform == DevicePlatform.ios ? appStore : googlePlay;
    final language = locale.languageCode;
    return [
      for (final t in known)
        if (t == language || t.startsWith('$language-')) t,
    ];
  }
}
