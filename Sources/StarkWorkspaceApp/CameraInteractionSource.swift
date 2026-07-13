import AirHandsCore
import AirHandsVision
import Foundation

final class CameraInteractionSource {
    private let source = VisionHandPoseSource()
    private let arbiter = IntentArbiter()
    private let store: AppStore

    init(store: AppStore) { self.store = store }

    func start() throws {
        source.onHands = { [weak self] hands, timestampMs in
            guard let self else { return }
            let events = arbiter.process(hands: hands, timestampMs: timestampMs)
            Task { @MainActor in events.forEach(self.store.handle) }
        }
        try source.start()
    }

    func cancel() {
        source.stop()
        let events = arbiter.cancel()
        Task { @MainActor in events.forEach(self.store.handle) }
    }
}
