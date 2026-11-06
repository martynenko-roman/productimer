#!/bin/zsh
# Workspace-safe SwiftPM caches. Also works around stale private manifest
# interfaces in mixed Command Line Tools installations without modifying them.
set -euo pipefail
repo=${0:A:h:h}
cache="${PRODUCTIMER_CACHE:-/private/tmp/productimer-toolchain}"
mkdir -p "$cache"
export CLANG_MODULE_CACHE_PATH="$cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache/modules"
export DYLD_LIBRARY_PATH="$(xcode-select -p)/Library/Developer/usr/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
manifest="$(xcode-select -p)/usr/lib/swift/pm/ManifestAPI"
private="$manifest/PackageDescription.swiftmodule/arm64-apple-macos.private.swiftinterface"
public="$manifest/PackageDescription.swiftmodule/arm64-apple-macos.swiftinterface"
if [[ -f "$private" && -f "$public" ]] && ! cmp -s <(head -2 "$private") <(head -2 "$public"); then
  python3 - "$manifest" "$cache/ManifestAPI" <<'PY'
import shutil, sys
shutil.copytree(sys.argv[1], sys.argv[2], dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('*.private.swiftinterface'))
PY
  compiler="$(xcode-select -p)/usr/bin/swiftc"
  # Python emits a wrapper with shell-quoted absolute paths.
  python3 - "$cache/swiftc" "$manifest" "$cache/ManifestAPI" "$compiler" <<'PY'
import sys, shlex, os
path, original, sanitized, compiler = sys.argv[1:]
with open(path, 'w') as f:
    f.write('#!/bin/zsh\nargs=()\nfor arg in "$@"; do\n')
    f.write('if [[ "$arg" == '+shlex.quote(original)+' ]]; then\nargs+=('+shlex.quote(sanitized)+')\nelse\nargs+=("$arg")\nfi\ndone\n')
    f.write('exec '+shlex.quote(compiler)+' -F /Library/Developer/CommandLineTools/Library/Developer/Frameworks -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks "${args[@]}"\n')
os.chmod(path, 0o755)
PY
  export SWIFT_EXEC="$cache/swiftc"
fi
command=${1:-build}
shift || true
exec swift "$command" --disable-sandbox --package-path "$repo" \
  --cache-path "$cache/cache" --config-path "$cache/config" --security-path "$cache/security" \
  --scratch-path "$cache/build" -Xlinker -rpath -Xlinker "$(xcode-select -p)/Library/Developer/usr/lib" "$@"
