#!/bin/bash
# Runs the checks for one architecture on the connected device or emulator.
#
# Usage: run-checks.sh <arch> <products-dir> <swift-sdk-dir>
#   arch           aarch64, armv7 or x86_64
#   products-dir   directory with the FoundationCheck and RuntimeCheck executables for <arch>
#   swift-sdk-dir  the swift-android directory of the Swift SDK for Android (with ndk-sysroot set up)
#
# Prints one line per check and exits with 1 if any check fails or the device can't run <arch>.
set -uo pipefail

ARCH=$1
PRODUCTS=$2
SDK=$3
HERE=$(cd "$(dirname "$0")" && pwd)
ADB=${ADB:-adb}

case $ARCH in
    aarch64) ABI=arm64-v8a; NDK_TRIPLE=aarch64-linux-android ;;
    armv7) ABI=armeabi-v7a; NDK_TRIPLE=arm-linux-androideabi ;;
    x86_64) ABI=x86_64; NDK_TRIPLE=x86_64-linux-android ;;
    *) echo "unknown arch: $ARCH"; exit 2 ;;
esac

ABILIST=$($ADB shell getprop ro.product.cpu.abilist | tr -d '\r')
echo "device ABIs: $ABILIST"
if [[ ",$ABILIST," != *",$ABI,"* ]]; then
    echo "FAIL $ARCH: the device doesn't run $ABI"
    exit 1
fi

# The executables, the Swift libraries from the SDK and libc++_shared.so from the NDK.
STAGING=$(mktemp -d)
cp "$PRODUCTS/FoundationCheck" "$PRODUCTS/RuntimeCheck" "$STAGING/"
cp "$SDK/swift-resources/usr/lib/swift-$ARCH/android/"*.so "$STAGING/"
cp -L "$SDK/ndk-sysroot/usr/lib/$NDK_TRIPLE/libc++_shared.so" "$STAGING/"
DIR=/data/local/tmp/swift-android-check-$ARCH
$ADB shell rm -rf "$DIR" > /dev/null
$ADB push "$STAGING" "$DIR" > /dev/null
rm -rf "$STAGING"
RUN="cd $DIR && LD_LIBRARY_PATH=$DIR"

failures=0

OUTPUT=$(mktemp)
$ADB shell "$RUN ./FoundationCheck" | tr -d '\r' > "$OUTPUT"
if diff -u "$HERE/../expected/foundation.txt" "$OUTPUT"; then
    echo "ok foundation"
else
    echo "FAIL foundation"
    failures=$((failures + 1))
fi
rm -f "$OUTPUT"

for check in $($ADB shell "$RUN ./RuntimeCheck --list" | tr -d '\r'); do
    result=$($ADB shell "$RUN ./RuntimeCheck $check 2>&1; echo exit=\$?" | tr -d '\r')
    if [[ "$result" == *"ok $check"* && "$result" == *"exit=0"* ]]; then
        echo "ok $check"
    else
        echo "FAIL $check: $(echo "$result" | tail -3 | tr '\n' ' ')"
        failures=$((failures + 1))
    fi
done

echo "$ARCH: $failures failed"
[[ $failures == 0 ]]
