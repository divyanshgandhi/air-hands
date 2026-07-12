import AirHandsCore
import Foundation

public final class WorkspaceModel {
    public var panels: [WorkspacePanel]
    public var selectedID: UUID?
    public var pointer = Point(x: 0.5, y: 0.5)
    public var isEngaged = false
    public var isOverview = false
    public var status = "Dormant"

    public init(panels: [WorkspacePanel], selectedID: UUID? = nil) {
        self.panels = panels
        self.selectedID = selectedID ?? panels.first?.id
    }

    public var selectedPanel: WorkspacePanel? {
        guard let selectedID else { return nil }
        return panels.first { $0.id == selectedID }
    }

    public static var demo: WorkspaceModel {
        let panels = [
            WorkspacePanel(title: "Systems", detail: "Native controls", frame: .init(x: 0.36, y: 0.24, width: 0.30, height: 0.38), zIndex: 3),
            WorkspacePanel(title: "Windows", detail: "Active Mac apps", frame: .init(x: 0.10, y: 0.31, width: 0.25, height: 0.31), zIndex: 2),
            WorkspacePanel(title: "Files", detail: "Recent workspace", frame: .init(x: 0.67, y: 0.31, width: 0.23, height: 0.31), zIndex: 1),
        ]
        return WorkspaceModel(panels: panels)
    }
}
