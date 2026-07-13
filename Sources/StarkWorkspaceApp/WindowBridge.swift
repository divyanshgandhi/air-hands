import ApplicationServices
import StarkWorkspaceCore

enum PermissionState { case denied, granted }

final class WindowBridge {
    var permission: PermissionState { AXIsProcessTrusted() ? .granted : .denied }

    func execute(_ command: WindowCommand) throws {
        guard permission == .granted else { return }
        let parts: [Substring]
        switch command {
        case let .focus(id), let .move(id, _), let .resize(id, _): parts = id.split(separator: ":")
        }
        guard let pidText = parts.first, let pid = Int32(pidText) else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementPerformAction(app, kAXRaiseAction as CFString)
    }
}
