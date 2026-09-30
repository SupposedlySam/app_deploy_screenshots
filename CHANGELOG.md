## 1.1.0

- fix: `byDevices` passes `deviceSetup` through to `byDevice`, which now runs it inside that device's overrides
- fix: images are waited for per device, after the pumps, and painted before capture. Previously images laid out again at a new device size (list tiles, `ResizeImage`) were captured blank
- fix: `Device.safeArea` is in logical points and is scaled by `devicePixelRatio` when applied. Previously apps saw about a ninth of the real inset (6.6pt instead of 59pt on iPhone), and the built-in insets now match the real devices
- feat: `byDevice` takes `deviceSetup` and `applyDeviceOverrides`

## 1.0.1

- fix: pass all args through from `byPlatform` to `byDevices`

## 1.0.0

- feat: Initial Release
