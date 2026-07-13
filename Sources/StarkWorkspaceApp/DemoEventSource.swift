import AirHandsCore
import Foundation

@MainActor
final class DemoEventSource {
    private let store: AppStore
    private var timer: Timer?
    private var step = 0
    private let events: [InteractionEvent] = [
        .engagementChanged(true),
        .pointerMoved(Point(x: 0.50, y: 0.42)),
        .grabBegan(Point(x: 0.50, y: 0.42)),
        .grabMoved(Point(x: 0.56, y: 0.48)),
        .grabEnded(Point(x: 0.56, y: 0.48)),
        .zoom(scaleDelta: 1.18),
        .switchWorkspace(direction: 1),
        .overview(true),
        .overview(false),
    ]

    init(store: AppStore) { self.store = store }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
        advance()
    }

    func advance() {
        store.handle(events[step % events.count])
        step += 1
    }
}
