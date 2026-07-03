import ConformanceKit
import Foundation

// Usage: swift run airhands-conformance [path-to-vectors-dir]
// Defaults to the repo's canonical vectors when run from a dev checkout.

let defaultDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // airhands-conformance/
    .deletingLastPathComponent() // Sources/
    .deletingLastPathComponent() // repo root
    .appendingPathComponent("Tests/AirHandsCoreTests/Vectors")

let dir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : defaultDir

do {
    let failures = try ConformanceRunner.runAll(vectorsDir: dir)
    if failures.isEmpty {
        print("CONFORMANT — Swift engine matches the TypeScript reference exactly")
        exit(0)
    }
    print("\(failures.count) failure(s):")
    for failure in failures {
        print("  ✘ \(failure)")
    }
    exit(1)
} catch {
    print("error: \(error)")
    exit(2)
}
