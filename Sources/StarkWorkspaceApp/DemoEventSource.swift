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
        .scroll(delta: Point(x: 0, y: 0.08)),
        .switchWorkspace(direction: 1),
        .overview(true),
        .overview(false),
        .minimizeSelected,
        .dismissSelected,
        .engagementChanged(false),
    ]

    init(store: AppStore) { self.store = store }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
        advance()
    }

    func advance() {
        guard step < events.count else {
            store.resetDemo()
            step = 0
            return
        }
        store.handle(events[step])
        step += 1
    }
}
