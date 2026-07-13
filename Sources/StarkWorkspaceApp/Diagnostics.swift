import Foundation

@MainActor
final class Diagnostics {
    private var frameTimes: [Double] = []
    private(set) var fps = 0.0
    private(set) var latencyMs = 0.0

    func record(capturedAtMs: Double, displayedAtMs: Double = ProcessInfo.processInfo.systemUptime * 1000) {
        latencyMs = max(0, displayedAtMs - capturedAtMs)
        frameTimes.append(displayedAtMs)
        frameTimes.removeAll { displayedAtMs - $0 > 1000 }
        fps = Double(frameTimes.count)
    }
}
