import CxxChecks
import Dispatch

#if canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#endif

/// Runs one check per process, so a check that aborts doesn't hide the others.
///
///     RuntimeCheck --list    prints the names of all checks
///     RuntimeCheck <name>    runs one check and prints "ok <name>" or "FAIL <name>"
@main
struct RuntimeCheck {
    static func main() async {
        let arguments = CommandLine.arguments.dropFirst()
        if arguments.first == "--list" {
            for check in checks {
                print(check.name)
            }
            return
        }
        guard let name = arguments.first, let check = checks.first(where: { $0.name == name }) else {
            print("usage: RuntimeCheck --list | RuntimeCheck <name>")
            exit(2)
        }
        let passed = await check.run()
        print("\(passed ? "ok" : "FAIL") \(name)")
        exit(passed ? 0 : 1)
    }
}

struct Check: Sendable {
    let name: String
    let run: @Sendable () async -> Bool
}

private func cxx(_ name: String, _ function: @escaping @Sendable () -> Int32) -> Check {
    Check(name: name) { function() == 1 }
}

let checks: [Check] = [
    cxx("cxx-throw-catch", cxx_check_throw_catch),
    cxx("cxx-catch-by-base", cxx_check_catch_base),
    cxx("cxx-rethrow", cxx_check_rethrow),
    cxx("cxx-bad-alloc", cxx_check_bad_alloc),
    cxx("cxx-dynamic-cast", cxx_check_dynamic_cast),
    cxx("cxx-typeid", cxx_check_typeid),
    cxx("cxx-static-init-threads", cxx_check_static_init_threads),
    cxx("cxx-nested", cxx_check_nested),
    cxx("cxx-exception-ptr-across-threads", cxx_check_exception_ptr),
    cxx("cxx-future-from-async", cxx_check_future_async),
    cxx("cxx-promise-set-exception", cxx_check_promise_thread),
    cxx("cxx-swift-exception-bridge-shim", cxx_check_swift_exception_bridge),
    Check(name: "async-let") {
        async let first = work(1)
        async let second = work(2)
        return ((try? await first) ?? 0) + ((try? await second) ?? 0) == 3
    },
    Check(name: "task-group") {
        let sum = await withTaskGroup(of: Int.self) { group in
            for value in 1...100 {
                group.addTask { value }
            }
            return await group.reduce(0, +)
        }
        return sum == 5050
    },
    Check(name: "actor") {
        let counter = Counter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1000 {
                group.addTask { await counter.increment() }
            }
        }
        return await counter.value == 1000
    },
    Check(name: "async-throw") {
        do {
            _ = try await work(-5)
            return false
        } catch let error as WorkError {
            return error.code == -5
        } catch {
            return false
        }
    },
    Check(name: "sleep") {
        let start = DispatchTime.now().uptimeNanoseconds
        try? await Task.sleep(nanoseconds: 20_000_000)
        return DispatchTime.now().uptimeNanoseconds - start >= 20_000_000
    },
    Check(name: "continuation") {
        let value = await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(5)) {
                continuation.resume(returning: 7)
            }
        }
        return value == 7
    },
    Check(name: "cancellation") {
        let task = Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }
        task.cancel()
        return (try? await task.value) == nil && task.isCancelled
    },
    Check(name: "async-stream") {
        let stream = AsyncStream<Int> { continuation in
            for value in 1...10 {
                continuation.yield(value)
            }
            continuation.finish()
        }
        var sum = 0
        for await value in stream {
            sum += value
        }
        return sum == 55
    },
    Check(name: "detached-priorities") {
        let sum = await withTaskGroup(of: Int.self) { group in
            group.addTask { await Task.detached(priority: .background) { 1 }.value }
            group.addTask { await Task.detached(priority: .high) { 2 }.value }
            return await group.reduce(0, +)
        }
        return sum == 3
    },
]

private actor Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private struct WorkError: Error {
    let code: Int
}

private func work(_ code: Int) async throws -> Int {
    try await Task.sleep(nanoseconds: 1_000_000)
    if code < 0 { throw WorkError(code: code) }
    return code
}
