#!/bin/zsh
set -euo pipefail
repo=${0:A:h:h}
work=$(mktemp -d /private/tmp/Productimer-selftest.XXXXXX)
APP_STORE="$work/timer.json" "$repo/build/Productimer.app/Contents/MacOS/Productimer" --selftest
