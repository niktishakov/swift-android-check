// swift-tools-version: 6.0
import PackageDescription

// Command-line checks for the Swift SDK for Android. Each one prints its results to stdout,
// so it can run on a device or emulator with `adb shell`.
let package = Package(
    name: "swift-android-check",
    products: [
        .executable(name: "FoundationCheck", targets: ["FoundationCheck"]),
        .executable(name: "RuntimeCheck", targets: ["RuntimeCheck"]),
    ],
    targets: [
        // Formats dates, numbers and durations, converts encodings and runs ICU transforms and regexes.
        // The runpath lets it find the Swift libraries next to it: under Android's ARM translation,
        // LD_LIBRARY_PATH doesn't reach the program.
        .executableTarget(
            name: "FoundationCheck",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "$ORIGIN"])]
        ),
        // C++ exception handling and Swift Concurrency, one check per process.
        .executableTarget(name: "RuntimeCheck", dependencies: ["CxxChecks"]),
        .target(name: "CxxChecks"),
    ],
    cxxLanguageStandard: .cxx17
)
