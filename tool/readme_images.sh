#!/usr/bin/env bash
# Regenerates the README images in doc/images/ from the example app's store
# screenshots. Maintainers only; needs ImageMagick (`magick`) and fvm.
#
#   tool/readme_images.sh
#
# The images are excluded from the published package (.pubignore) and the
# README links to them on GitHub, so commit and push after regenerating.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo/doc/images"
shots="$repo/example/app_deploy_screenshots"

(cd "$repo/example" && rm -rf app_deploy_screenshots && fvm flutter test test/store_screenshots_test.dart)

ios="$shots/ios/app_store_iphone_6_9"
ipad="$shots/ios/app_store_ipad_13"
play="$shots/android"
bg='#F4F4F5'
mkdir -p "$out"

# Several screenshots side by side at one height, on a neutral background.
row() {
  local height=$1 dest=$2
  shift 2
  magick "$@" -resize "x$height" -background "$bg" -splice 32x0 +append \
    -chop 32x0 -bordercolor "$bg" -border 32 -strip "$dest"
}

row 640 "$out/hero.png" \
  "$ios/01_inbox.light.en.png" "$ios/01_inbox.dark.fr.png" \
  "$play/play_store_phone/01_inbox.light.en.png" "$ios/02_features.png"

row 520 "$out/store_sizes.png" \
  "$ios/01_inbox.light.en.png" "$ipad/01_inbox.light.en.png" \
  "$play/play_store_phone/01_inbox.light.en.png" \
  "$play/play_store_tablet_7/01_inbox.light.en.png" \
  "$play/play_store_tablet_10/01_inbox.light.en.png"

row 720 "$out/annotations.png" "$ios/02_features.png" "$ios/03_plain.png"

row 640 "$out/variants.png" \
  "$ios/01_inbox.light.en.png" "$ios/01_inbox.dark.en.png" \
  "$ios/01_inbox.light.fr.png" "$ios/01_inbox.dark.fr.png"

magick "$shots/_review/ios__app_store_iphone_6_9.png" -resize 1400x -strip \
  "$out/contact_sheet.png"

ls -la "$out"
