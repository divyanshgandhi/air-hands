import AirHandsCore
import Foundation

public final class WorkspaceController {
    public let model: WorkspaceModel
    public var onWindowCommand: ((WindowCommand) -> Void)?
    private var grabStart: (point: Point, frame: NormalizedRect)?

    public init(model: WorkspaceModel) {
        self.model = model
    }

    public func handle(_ event: InteractionEvent) {
        switch event {
        case let .engagementChanged(active):
            model.isEngaged = active
            model.status = active ? "Engaged" : "Dormant"
            if !active { grabStart = nil }
        case let .pointerMoved(point):
            model.pointer = point
            selectPanel(at: point)
        case let .grabBegan(point):
            selectPanel(at: point)
            if let panel = model.selectedPanel { grabStart = (point, panel.frame) }
        case let .grabMoved(point):
            moveGrab(to: point)
        case .grabEnded:
            grabStart = nil
        case let .scroll(delta):
            model.status = String(format: "Scroll %.2f", delta.y)
        case let .zoom(scale):
            resizeSelected(by: scale)
        case let .switchWorkspace(direction):
            switchPanel(direction: direction)
        case let .overview(active):
            model.isOverview = active
            model.status = active ? "Overview" : "Engaged"
        case .cancelled:
            grabStart = nil
            model.isEngaged = false
            model.isOverview = false
            model.status = "Dormant"
        }
    }

    private func selectPanel(at point: Point) {
        model.selectedID = model.panels.filter { panel in
            let frame = panel.frame
            return !panel.isMinimized && point.x >= frame.x && point.x <= frame.x + frame.width &&
                point.y >= frame.y && point.y <= frame.y + frame.height
        }.max(by: { $0.zIndex < $1.zIndex })?.id ?? model.selectedID
    }

    private func moveGrab(to point: Point) {
        guard let grabStart, let index = model.panels.firstIndex(where: { $0.id == model.selectedID }) else { return }
        model.panels[index].frame.x = clamp(grabStart.frame.x + point.x - grabStart.point.x, 0, 1 - grabStart.frame.width)
        model.panels[index].frame.y = clamp(grabStart.frame.y + point.y - grabStart.point.y, 0, 1 - grabStart.frame.height)
        if let windowID = model.panels[index].windowID { onWindowCommand?(.move(windowID, model.panels[index].frame)) }
    }

    private func resizeSelected(by scale: Double) {
        guard let index = model.panels.firstIndex(where: { $0.id == model.selectedID }) else { return }
        model.panels[index].frame.width = clamp(model.panels[index].frame.width * scale, 0.18, 0.8)
        model.panels[index].frame.height = clamp(model.panels[index].frame.height * scale, 0.14, 0.8)
        if let windowID = model.panels[index].windowID { onWindowCommand?(.resize(windowID, model.panels[index].frame)) }
    }

    private func switchPanel(direction: Int) {
        guard !model.panels.isEmpty else { return }
        let current = model.panels.firstIndex { $0.id == model.selectedID } ?? 0
        model.selectedID = model.panels[(current + (direction >= 0 ? 1 : model.panels.count - 1)) % model.panels.count].id
        if let windowID = model.selectedPanel?.windowID { onWindowCommand?(.focus(windowID)) }
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
