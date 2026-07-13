import AirHandsCore
import Combine
import StarkWorkspaceCore
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var model = WorkspaceModel.demo
    lazy var controller: WorkspaceController = {
        let controller = WorkspaceController(model: model)
        controller.onWindowCommand = { [weak self] command in try? self?.windowBridge.execute(command) }
        return controller
    }()
    let windowBridge = WindowBridge()
    let diagnostics = Diagnostics()

    func handle(_ event: InteractionEvent) {
        objectWillChange.send()
        controller.handle(event)
    }

    func cancel() {
        handle(.cancelled)
    }

    func loadSystemWindows() {
        guard windowBridge.permission == .granted else {
            model.status = "Accessibility needed for Mac windows"
            return
        }
        let windows = windowBridge.eligibleWindows().prefix(3)
        for (index, window) in windows.enumerated() {
            model.panels.append(WorkspacePanel(
                title: window.appName,
                detail: window.title,
                frame: NormalizedRect(x: 0.08 + Double(index) * 0.16, y: 0.68, width: 0.22, height: 0.20),
                zIndex: index,
                windowID: window.id
            ))
        }
    }

    func resetDemo() {
        let demo = WorkspaceModel.demo
        model.panels = demo.panels
        model.selectedID = demo.selectedID
        model.pointer = demo.pointer
        model.isEngaged = false
        model.isOverview = false
        model.status = "Dormant"
        objectWillChange.send()
    }
}
