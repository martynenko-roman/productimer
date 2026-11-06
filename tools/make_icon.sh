#!/bin/zsh
# Compiles Icon/AppIcon.icon (an Icon Composer file) with actool and writes:
#   Resources/Assets.car     the Liquid Glass icon (light, dark, tinted, clear)
#   Resources/AppIcon.icns   flat fallback for Finder views that read .icns
# build.sh runs this when the .icon changed. Run it by hand to check errors.
set -euo pipefail
here=${0:A:h}
repo=${here:h}
icon="$repo/Icon/AppIcon.icon"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$repo/Resources"

if ! xcrun --find actool >/dev/null 2>&1; then
  export CLANG_MODULE_CACHE_PATH="${PRODUCTIMER_CACHE:-/private/tmp/productimer-toolchain}/clang"
  swift "$repo/tools/fallback-icon.swift" "$work/AppIcon.iconset"
  python3 - "$work/AppIcon.iconset" "$repo/Resources/AppIcon.icns" <<'PYICON'
from pathlib import Path
import struct, sys
root = Path(sys.argv[1])
chunks = []
for tag, name in [('icp4','icon_16x16.png'), ('icp5','icon_32x32.png'), ('icp6','icon_32x32@2x.png'), ('ic07','icon_128x128.png'), ('ic08','icon_256x256.png'), ('ic09','icon_512x512.png'), ('ic10','icon_512x512@2x.png'), ('ic11','icon_16x16@2x.png'), ('ic12','icon_32x32@2x.png'), ('ic13','icon_128x128@2x.png'), ('ic14','icon_256x256@2x.png')]:
    data = (root/name).read_bytes()
    chunks.append(tag.encode() + struct.pack('>I', len(data)+8) + data)
body = b''.join(chunks)
Path(sys.argv[2]).write_bytes(b'icns' + struct.pack('>I', len(body)+8) + body)
PYICON
  cp "$work/AppIcon.iconset/icon_512x512@2x.png" "$repo/Resources/Icon-preview.png"
  echo "wrote Resources/AppIcon.icns (standard icon fallback; Xcode actool unavailable)"
  exit 0
fi
# actool fails on a missing layer image, so it doubles as the validator.
# The .icon must be named AppIcon.icon to match --app-icon, or actool
# writes nothing and still exits 0. Check the output to catch that.
xcrun actool "$icon" --compile "$work" --platform macosx \
  --minimum-deployment-target 26.0 --app-icon AppIcon \
  --output-partial-info-plist "$work/partial.plist" \
  --output-format human-readable-text --errors --warnings >"$work/log" 2>&1 || { cat "$work/log"; exit 1; }
[[ -f "$work/Assets.car" && -f "$work/AppIcon.icns" ]] || { cat "$work/log"; echo "actool wrote no icon"; exit 1; }
cp "$work/Assets.car" "$work/AppIcon.icns" "$repo/Resources/"
echo "wrote Resources/Assets.car and Resources/AppIcon.icns"
