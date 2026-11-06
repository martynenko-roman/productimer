#!/bin/zsh
set -euo pipefail
repo=${0:A:h:h}
work=$(mktemp -d /private/tmp/Productimer-snap.XXXXXX)
APP_STORE="$work/timer.json" APP_SNAPSHOT="${PRODUCTIMER_SHOTS:-/private/tmp/Productimer-shots}" "$repo/build/Productimer.app/Contents/MacOS/Productimer"
