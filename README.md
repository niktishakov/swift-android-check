# swift-android-check

Checks that a Swift SDK for Android works on all three Android architectures: aarch64, armv7 and x86_64.

It builds two small command-line programs with the SDK and runs them on an Android emulator in GitHub Actions:

- `FoundationCheck` formats dates, numbers, durations and relative dates in several locales, converts text encodings and runs ICU transforms and regexes. Its output must match [`expected/foundation.txt`](expected/foundation.txt).
- `RuntimeCheck` runs C++ exception handling checks (throw and catch, `std::exception_ptr` across threads, `std::nested_exception`, `std::future`, …) and Swift Concurrency checks. Each check runs in its own process, so a check that aborts doesn't hide the others.

The emulator is an x86_64 Android 11 image. x86_64 code runs natively; aarch64 and armv7 code runs through Android's ARM translation, which is not the same as real ARM hardware.

The arm64 translation stops `FoundationCheck` with `Illegal instruction`, while the same executable works on native arm64. This is listed in [`expected/emulator-limits.txt`](expected/emulator-limits.txt) and doesn't fail the run, so check aarch64 Foundation on a native arm64 device or emulator. GitHub's arm64 runners have no KVM, so they can't run a native arm64 emulator.

## Checking an SDK

- The released SDK is checked on every push.
- To check another build, run the **Check** workflow manually and pass the URL of its `.artifactbundle.tar.gz`.

Checks that fail with the released SDK are listed in [`expected/known-failures-6.4.1.txt`](expected/known-failures-6.4.1.txt). They don't fail the run, and the summary shows when one of them starts to pass. For any other SDK, every failure fails the run.

## Running locally

With the Swift SDK for Android installed and a device or emulator connected:

```sh
scripts/build.sh
ARCHS=aarch64 scripts/run-all.sh ~/Library/org.swift.swiftpm/swift-sdks/swift-6.4.1-RELEASE_android.artifactbundle/swift-android
```

`run-checks.sh` copies the executables, the SDK's Swift libraries and `libc++_shared.so` to `/data/local/tmp` and runs them with `adb shell`.

## License

Apache License 2.0. [`SwiftCxxExceptionShim.h`](Sources/CxxChecks/SwiftCxxExceptionShim.h) is a copy of the shim from [swiftlang/swift#92561](https://github.com/swiftlang/swift/pull/92561), licensed under the Apache License v2.0 with Runtime Library Exception.
