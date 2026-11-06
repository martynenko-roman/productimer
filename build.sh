#!/bin/zsh
# Build a signed app bundle inside this checkout; no external installation.
set -euo pipefail
here=${0:A:h}
config=release
[[ " $* " == *" --debug "* ]] && config=debug
"$here/tools/swift.sh" build -c "$config"
cache="${PRODUCTIMER_CACHE:-/private/tmp/productimer-toolchain}"
app="$here/build/Productimer.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$cache/build/$config/Productimer" "$app/Contents/MacOS/Productimer"
sed "s/__BUILD__/$(date +%Y%m%d%H%M)/" "$here/Info.plist.in" > "$app/Contents/Info.plist"
"$here/tools/make_icon.sh"
cp "$here/Resources/AppIcon.icns" "$app/Contents/Resources/"
if [[ -f "$here/Resources/Assets.car" ]]; then cp "$here/Resources/Assets.car" "$app/Contents/Resources/"; fi
codesign --force --sign "${SIGN_IDENTITY:--}" "$app"
echo "Built $app"
if [[ " $* " == *" --open "* ]]; then open "$app"; fi
