// Standard test entry point for environments with Xcode. Command Line
// Tools-only machines have neither XCTest nor Swift Testing — use
// `swift run airhands-conformance` there instead; it runs the same suite.
#if canImport(Testing)
import Foundation
import Testing

@testable import ConformanceKit

@Test func engineMatchesTypeScriptReference() throws {
    let vectors = try #require(
        Bundle.module.url(forResource: "Vectors", withExtension: nil),
        "missing bundled vectors"
    )
    let failures = try ConformanceRunner.runAll(vectorsDir: vectors)
    #expect(failures.isEmpty, "\(failures)")
}
#endif
