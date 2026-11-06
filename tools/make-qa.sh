#!/bin/zsh
# An independently launchable QA bundle uses a fresh temporary store.
set -euo pipefail
repo=${0:A:h:h}
mode=${1:-selftest}
[[ "$mode" == selftest || "$mode" == snapshots || "$mode" == manual || "$mode" == statistics || "$mode" == importer || "$mode" == importer-review ]] || exit 2
python3 - "$repo" "$mode" <<'PY'
import pathlib, plistlib, shutil, sys
repo, mode = pathlib.Path(sys.argv[1]), sys.argv[2]
source = repo/'build/Productimer.app'
target = repo/f'build/Productimer-{mode}.app'
shutil.copytree(source, target, dirs_exist_ok=True)
p = target/'Contents/Info.plist'
info = plistlib.loads(p.read_bytes())
info['CFBundleIdentifier'] = 'com.romanmartynenko.productimer.qa.' + mode
info['CFBundleName'] = 'Productimer QA ' + mode
info['ProductimerVerification'] = mode
p.write_bytes(plistlib.dumps(info))
print(target)
PY
codesign --force --sign - "$repo/build/Productimer-$mode.app"
