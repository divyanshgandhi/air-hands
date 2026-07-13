import AirHandsCore
import Combine
import StarkWorkspaceCore

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var model = WorkspaceModel.demo
    lazy var controller: WorkspaceController = {
        let controller = WorkspaceController(model: model)
        controller.onWindowCommand = { [weak self] command in try? self?.windowBridge.execute(command) }
        return controller
    }()
    let windowBridge = WindowBridge()

    func handle(_ event: InteractionEvent) {
        objectWillChange.send()
        controller.handle(event)
    }

    func cancel() {
        handle(.cancelled)
    }
}
