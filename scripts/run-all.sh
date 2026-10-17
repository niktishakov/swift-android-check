#!/bin/bash
# Runs the checks for every architecture on the connected device or emulator and writes a summary.
#
# Usage: run-all.sh <swift-sdk-dir> [known-failures-file]
#   swift-sdk-dir         the swift-android directory of the Swift SDK for Android
#   known-failures-file   checks that are expected to fail, one "<arch> <check>" per line
#
# The checks must already be built with build.sh. A failure listed in known-failures-file
# doesn't fail the run, and a listed check that passes is reported as fixed.
set -uo pipefail

SDK=$1
KNOWN=${2:-/dev/null}
HERE=$(cd "$(dirname "$0")" && pwd)
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/stdout}
ARCHS=${ARCHS:-aarch64 armv7 x86_64}

unexpected=0
{
    echo "| Arch | Passed | Failed (known) | Failed (new) | Fixed |"
    echo "|---|---|---|---|---|"
} >> "$SUMMARY"

for arch in $ARCHS; do
    echo "::group::$arch"
    log=$(mktemp)
    "$HERE/run-checks.sh" "$arch" "$("$HERE/build.sh" --show-bin-path "$arch")" "$SDK" | tee "$log"
    echo "::endgroup::"

    passed=0; known=0; new=0; fixed=0
    while read -r status name rest; do
        case $status in
            ok)
                passed=$((passed + 1))
                if grep -qx "$arch $name" "$KNOWN"; then
                    fixed=$((fixed + 1))
                    echo "fixed: $arch $name"
                fi
                ;;
            FAIL)
                name=${name%:}
                if grep -qx "$arch $name" "$KNOWN"; then
                    known=$((known + 1))
                else
                    new=$((new + 1))
                    echo "::error::$arch $name failed"
                fi
                ;;
        esac
    done < "$log"
    rm -f "$log"

    echo "| $arch | $passed | $known | $new | $fixed |" >> "$SUMMARY"
    unexpected=$((unexpected + new))
done

[[ $unexpected == 0 ]]
