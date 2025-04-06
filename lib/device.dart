/// ***************************************************
/// Copyright 2019-2020 eBay Inc.
///
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file or at
/// https://opensource.org/licenses/BSD-3-Clause
/// ***************************************************
library;

import 'dart:ui';

import 'package:flutter/widgets.dart';

enum DevicePlatform {
  ios,
  android,
}

/// Represents standard iOS device display sizes
enum DisplaySize {
  // iPhones
  threeFive(3.5),
  four(4.0),
  fourSeven(4.7),
  fiveFive(5.5),
  sixOne(6.1),
  sixThree(6.3),
  sixFive(6.5),
  sixNine(6.9),

  // iPads
  nineSeven(9.7),
  tenFive(10.5),
  eleven(11.0),
  twelveNine(12.9),
  thirteen(13.0);

  const DisplaySize(this.inches);
  final double inches;

  String get label => '$inches';

  @override
  String toString() => label;
}

/// Represents standard device display sizes and types
enum DeviceType { phone, tablet, chromebook, tv, wear }

/// This [Device] is a configuration for golden test. Can be provided for [multiScreenGolden]
///
/// Check these locations for the latest specs:
/// Apple: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/
/// Google: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en&sjid=9437801895573353493-NA#zippy=%2Cscreenshots
class Device {
  /// This [Device] is a configuration for golden test. Can be provided for [multiScreenGolden]
  const Device({
    required this.size,
    required this.name,
    required this.displaySize,
    required this.platform,
    this.devicePixelRatio = 1.0,
    this.textScale = 1.0,
    this.brightness = Brightness.light,
    this.safeArea = const EdgeInsets.all(0),
  });

  /// [phone] one of the smallest phone screens
  static const Device phone = Device(
    name: 'phone',
    size: Size(375, 667),
    displaySize: DisplaySize.fourSeven, // iPhone 6/6s/7/8 size
    platform: DevicePlatform.ios,
  );

  /// [iphone11] matches specs of iphone11, but with lower DPI for performance
  static const Device iphone11 = Device(
    name: 'iphone11',
    size: Size(414, 896),
    displaySize: DisplaySize.sixOne,
    platform: DevicePlatform.ios,
    devicePixelRatio: 1.0,
    safeArea: EdgeInsets.only(top: 44, bottom: 34),
  );

  /// [tabletLandscape] example of tablet that in landscape mode
  static const Device tabletLandscape = Device(
    name: 'tablet_landscape',
    size: Size(1366, 1024),
    displaySize: DisplaySize.tenFive, // 10.5" iPad size in landscape
    platform: DevicePlatform.ios,
  );

  /// [tabletPortrait] example of tablet that in portrait mode
  static const Device tabletPortrait = Device(
    name: 'tablet_portrait',
    size: Size(1024, 1366),
    displaySize: DisplaySize.tenFive, // 10.5" iPad size in portrait
    platform: DevicePlatform.ios,
  );

  /// iPhone Devices (6.9")
  static const Device iphone16ProMax = Device(
    name: 'iphone16_pro_max',
    size: Size(430, 932), // 1290/3, 2796/3
    displaySize: DisplaySize.sixNine,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 59 / 3, bottom: 34 / 3),
  );

  /// iPhone Devices (6.5")
  static const Device iphone14Plus = Device(
    name: 'iphone14_plus',
    size: Size(428, 926), // 1284/3, 2778/3
    displaySize: DisplaySize.sixFive,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 47 / 3, bottom: 34 / 3),
  );

  /// iPhone Devices (6.3")
  static const Device iphone16Pro = Device(
    name: 'iphone16_pro',
    size: Size(393, 852), // 1179/3, 2556/3
    displaySize: DisplaySize.sixThree,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 59 / 3, bottom: 34 / 3),
  );

  /// iPhone Devices (6.1")
  static const Device iphone14 = Device(
    name: 'iphone14',
    size: Size(390, 844), // 1170/3, 2532/3
    displaySize: DisplaySize.sixOne,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 47 / 3, bottom: 34 / 3),
  );

  /// iPhone Devices (5.5")
  static const Device iphone8Plus = Device(
    name: 'iphone8_plus',
    size: Size(414, 736), // 1242/3, 2208/3
    displaySize: DisplaySize.fiveFive,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 20 / 3, bottom: 0),
  );

  /// iPhone Devices (4.7")
  static const Device iphoneSE3 = Device(
    name: 'iphone_se_3',
    size: Size(375, 667), // 750/2, 1334/2
    displaySize: DisplaySize.fourSeven,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 20 / 2, bottom: 0),
  );

  /// iPad Devices (13")
  static const Device ipadProM4 = Device(
    name: 'ipad_pro_m4',
    size: Size(1032, 1376), // 2064/2, 2752/2
    displaySize: DisplaySize.thirteen,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.all(20 / 2),
  );

  /// iPad Devices (12.9")
  static const Device ipadPro12_9 = Device(
    name: 'ipad_pro_12_9',
    size: Size(1024, 1366), // 2048/2, 2732/2
    displaySize: DisplaySize.twelveNine,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.all(20 / 2),
  );

  /// iPad Devices (11")
  static const Device ipadPro11 = Device(
    name: 'ipad_pro_11',
    size: Size(834, 1194), // 1668/2, 2388/2
    displaySize: DisplaySize.eleven,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.all(20 / 2),
  );

  /// Mac (16:10 aspect ratio)
  static const Device macDefault = Device(
    name: 'mac_default',
    size: Size(1440, 900),
    displaySize: DisplaySize.thirteen, // Using largest size for Mac
    platform: DevicePlatform.ios,
  );

  /// Apple TV
  static const Device appleTV = Device(
    name: 'apple_tv',
    size: Size(1920, 1080),
    displaySize: DisplaySize.thirteen, // Using largest size for TV
    platform: DevicePlatform.ios,
  );

  /// Apple Vision Pro
  static const Device visionPro = Device(
    name: 'vision_pro',
    size: Size(3840, 2160),
    displaySize: DisplaySize.thirteen, // Using largest size for Vision Pro
    platform: DevicePlatform.ios,
  );

  /// Android Phone Screenshots - 16:9 aspect ratio
  static const Device androidPhoneWide = Device(
    name: 'android_phone_16_9',
    size: Size(640, 360), // 1920/3, 1080/3
    displaySize: DisplaySize.sixOne,
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24 / 3, bottom: 0),
  );

  /// Android Phone Screenshots - 9:16 aspect ratio
  static const Device androidPhone = Device(
    name: 'android_phone_9_16',
    size: Size(360, 640), // 1080/3, 1920/3
    displaySize: DisplaySize.sixOne,
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24 / 3, bottom: 0),
  );

  /// Android Phone Screenshots - 18:9 aspect ratio
  static const Device androidPhoneTall = Device(
    name: 'android_phone_18_9',
    size: Size(720, 360), // 2160/3, 1080/3
    displaySize: DisplaySize.sixThree,
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24 / 3, bottom: 0),
  );

  /// Android Phone Screenshots - 20:9 aspect ratio
  static const Device androidPhoneExtra = Device(
    name: 'android_phone_20_9',
    size: Size(800, 360), // 2400/3, 1080/3
    displaySize: DisplaySize.sixFive,
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24 / 3, bottom: 0),
  );

  /// Android Tablet Screenshots - 16:10 aspect ratio
  static const Device androidTablet = Device(
    name: 'android_tablet',
    size: Size(1280, 800), // 2560/2, 1600/2
    displaySize: DisplaySize.tenFive,
    platform: DevicePlatform.android,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.all(24 / 2),
  );

  /// Android TV Screenshots - 16:9 aspect ratio
  static const Device androidTV = Device(
    name: 'android_tv',
    size: Size(1920, 1080), // No scaling needed for TV
    displaySize: DisplaySize.thirteen,
    platform: DevicePlatform.android,
    devicePixelRatio: 1.0,
    safeArea: EdgeInsets.zero,
  );

  static const List<Device> allDevices = [
    iphone16ProMax,
    iphone16Pro,
    iphone14Plus,
    iphone14,
    iphone11,
    iphone8Plus,
    iphoneSE3,
    phone,
    ipadProM4,
    ipadPro12_9,
    ipadPro11,
    androidPhone,
    androidPhoneWide,
    androidPhoneTall,
    androidPhoneExtra,
    androidTablet,
    androidTV,
    visionPro,
    macDefault,
    appleTV,
  ];

  static List<Device> byPlatform(DevicePlatform platform) {
    return allDevices.where((device) => device.platform == platform).toList();
  }

  /// [name] specify device name. Ex: Phone, Tablet, Watch

  final String name;

  /// [size] specify device screen size. Ex: Size(1366, 1024))
  final Size size;

  /// [devicePixelRatio] specify device Pixel Ratio
  final double devicePixelRatio;

  /// [textScale] specify custom text scale
  final double textScale;

  /// [brightness] specify platform brightness
  final Brightness brightness;

  /// [safeArea] specify insets to define a safe area
  final EdgeInsets safeArea;

  /// [displaySize] specify display size
  final DisplaySize displaySize;

  /// [platform] specify platform
  final DevicePlatform platform;

  /// Filter devices by display size
  static List<Device> byDisplaySize(DisplaySize size) {
    return [
      iphone16ProMax,
      iphone16Pro,
      iphone14Plus,
      iphone14,
      iphone11,
      iphone8Plus,
      iphoneSE3,
      phone,
      ipadProM4,
      ipadPro12_9,
      ipadPro11,
      // Add any other device constants here
    ].where((device) => device.displaySize == size).toList();
  }

  /// [copyWith] convenience function for [Device] modification
  Device copyWith({
    Size? size,
    double? devicePixelRatio,
    String? name,
    double? textScale,
    Brightness? brightness,
    EdgeInsets? safeArea,
    DisplaySize? displaySize,
    DevicePlatform? platform,
  }) {
    return Device(
      size: size ?? this.size,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      name: name ?? this.name,
      textScale: textScale ?? this.textScale,
      brightness: brightness ?? this.brightness,
      safeArea: safeArea ?? this.safeArea,
      displaySize: displaySize ?? this.displaySize,
      platform: platform ?? this.platform,
    );
  }

  /// [dark] convenience method to copy the current device and apply dark theme
  Device dark() {
    return Device(
      size: size,
      devicePixelRatio: devicePixelRatio,
      textScale: textScale,
      brightness: Brightness.dark,
      safeArea: safeArea,
      displaySize: displaySize,
      platform: platform,
      name: '${name}_dark',
    );
  }

  /// Helper method to get screenshot configurations
  static List<Device> androidScreenshots({DeviceType type = DeviceType.phone}) {
    switch (type) {
      case DeviceType.phone:
        return [
          androidPhoneWide, // 16:9
          androidPhoneTall, // 18:9
          androidPhoneExtra, // 20:9
        ];
      case DeviceType.tablet:
        return [androidTablet]; // 16:10
      case DeviceType.tv:
        return [androidTV]; // 16:9
      default:
        return [androidPhoneTall]; // Default to common phone size
    }
  }

  /// Helper method to check if device meets minimum resolution requirements
  bool meetsPlayStoreRequirements() {
    // Minimum requirements from Play Store
    const minWidth = 320;
    const minHeight = 320;
    const maxWidth = 3840;
    const maxHeight = 3840;

    return size.width >= minWidth &&
        size.height >= minHeight &&
        size.width <= maxWidth &&
        size.height <= maxHeight;
  }

  @override
  String toString() {
    return 'Device: $name, ${size.width}x${size.height} @ $devicePixelRatio, text: $textScale, $brightness, safe: $safeArea';
  }
}
