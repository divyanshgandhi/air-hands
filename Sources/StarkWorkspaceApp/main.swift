import AppKit

@main
@MainActor
final class StarkWorkspaceApp: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private var overlay: OverlayWindow?
    private var demo: DemoEventSource?
    private var camera: CameraInteractionSource?
    private var monitors: [Any] = []

    static func main() {
        let app = NSApplication.shared
        let delegate = StarkWorkspaceApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlay = OverlayWindow(store: store)
        self.overlay = overlay
        overlay.orderFrontRegardless()
        installEscape()

        if CommandLine.arguments.contains("--demo") {
            let demo = DemoEventSource(store: store)
            self.demo = demo
            demo.start()
        } else {
            let camera = CameraInteractionSource(store: store)
            self.camera = camera
            do { try camera.start() }
            catch {
                store.model.status = "Camera unavailable"
                store.objectWillChange.send()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        camera?.cancel()
        store.cancel()
    }

    private func installEscape() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            if event.keyCode == 53 { Task { @MainActor in self?.store.cancel() } }
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler) { monitors.append(monitor) }
        let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
            return event.keyCode == 53 ? nil : event
        }
        monitors.append(local as Any)
    }
}
