#!/usr/bin/env bash
# Regenerates the README images in doc/images/2.0/ from the example app's
# store listing and feature gallery tests. Maintainers only; needs ImageMagick (`magick`) and fvm.
#
#   tool/readme_images.sh
#
# The images are excluded from the published package (.pubignore) and the
# README links to them on GitHub, so commit and push after regenerating.
# Each major version gets its own folder: published READMEs link to main,
# so replacing an older version's images would change its pub.dev page.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo/doc/images/2.0"
shots="$repo/example/app_deploy_screenshots"

(cd "$repo/example" && rm -rf app_deploy_screenshots &&
  fvm flutter test test/store_screenshots_test.dart test/feature_gallery_test.dart)

ios="$shots/ios/app_store_iphone_6_9"
ipad="$shots/ios/app_store_ipad_13"
play="$shots/android"
gallery="$shots/gallery"
bg='#F4F4F5'
mkdir -p "$out"

# Several screenshots side by side at one height, on a neutral background,
# [gap] pixels apart.
row() {
  local height=$1 gap=$2 dest=$3
  shift 3
  magick "$@" -resize "x$height" -background "$bg" -splice "${gap}x0" +append \
    -chop "${gap}x0" -bordercolor "$bg" -border 32 -strip "$dest"
}
slides() { ls "$gallery/$1/ios/app_store_iphone_6_9/"*.png; }

row 640 32 "$out/listing.png" \
  "$ios/01_welcome.light.en_US.png" "$ios/02_inbox.light.en_US.png" \
  "$ios/03_conversation.dark.en_US.png" "$ios/04_two_screens.light.en_US.png"

row 520 32 "$out/store_sizes.png" \
  "$ios/02_inbox.light.en_US.png" "$ipad/02_inbox.light.en_US.png" \
  "$play/play_store_phone/02_inbox.light.en_US.png" \
  "$play/play_store_tablet_7/02_inbox.light.en_US.png" \
  "$play/play_store_tablet_10/02_inbox.light.en_US.png"

row 560 32 "$out/variants.png" \
  "$ios/02_inbox.light.en_US.png" "$ios/02_inbox.dark.en_US.png" \
  "$ios/02_inbox.light.fr_FR.png" "$ios/02_inbox.dark.fr_FR.png"

row 560 32 "$out/widget_slides.png" \
  "$ios/01_welcome.dark.en_US.png" "$ios/04_two_screens.dark.en_US.png" \
  "$ipad/04_two_screens.light.en_US.png"

# shellcheck disable=SC2046 # one argument per slide
row 560 32 "$out/layouts.png" $(slides layouts)
# shellcheck disable=SC2046
row 560 32 "$out/captions.png" $(slides captions)
# shellcheck disable=SC2046
row 560 32 "$out/annotations.png" $(slides annotations)
# Thin gaps, so the joins between the slides show.
# shellcheck disable=SC2046
row 560 6 "$out/panorama.png" $(slides panorama)

magick "$shots/_review/ios__app_store_iphone_6_9.png" -resize 1400x -strip \
  "$out/contact_sheet.png"

ls -la "$out"
