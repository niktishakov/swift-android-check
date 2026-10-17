#!/bin/bash
# Builds the checks for Android.
#
# Usage: build.sh [arch...]                 builds for the given architectures (default: all)
#        build.sh --show-bin-path <arch>    prints the directory with the executables for <arch>
set -euo pipefail

API=${ANDROID_API:-28}
SWIFT=${SWIFT:-swift}
cd "$(dirname "$0")/.."

sdk_for() {
    echo "$1-unknown-linux-android$API"
}

if [[ ${1:-} == --show-bin-path ]]; then
    "$SWIFT" build -c release --swift-sdk "$(sdk_for "$2")" --show-bin-path
    exit
fi

for arch in ${@:-aarch64 armv7 x86_64}; do
    "$SWIFT" build -c release --swift-sdk "$(sdk_for "$arch")"
done
