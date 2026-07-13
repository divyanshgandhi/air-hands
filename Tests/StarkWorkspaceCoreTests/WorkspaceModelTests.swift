import AirHandsCore
import StarkWorkspaceCore
import XCTest

final class WorkspaceModelTests: XCTestCase {
    func testGrabMovesSelectedPanel() {
        let model = WorkspaceModel.demo
        let controller = WorkspaceController(model: model)
        let start = model.selectedPanel!.frame
        controller.handle(.grabBegan(Point(x: 0.5, y: 0.5)))
        controller.handle(.grabMoved(Point(x: 0.6, y: 0.6)))
        XCTAssertEqual(model.selectedPanel!.frame.x, start.x + 0.1, accuracy: 0.0001)
        XCTAssertEqual(model.selectedPanel!.frame.y, start.y + 0.1, accuracy: 0.0001)
    }

    func testZoomClampsPanelSize() {
        let model = WorkspaceModel.demo
        let controller = WorkspaceController(model: model)
        controller.handle(.zoom(scaleDelta: 0.01))
        XCTAssertGreaterThanOrEqual(model.selectedPanel!.frame.width, 0.18)
        XCTAssertGreaterThanOrEqual(model.selectedPanel!.frame.height, 0.14)
    }

    func testSwitchAndOverview() {
        let model = WorkspaceModel.demo
        let controller = WorkspaceController(model: model)
        let first = model.selectedPanel!.id
        controller.handle(.switchWorkspace(direction: 1))
        XCTAssertNotEqual(model.selectedPanel!.id, first)
        controller.handle(.overview(true))
        XCTAssertTrue(model.isOverview)
    }

    func testMinimizeSelectedPanel() {
        let model = WorkspaceModel.demo
        let controller = WorkspaceController(model: model)
        let selected = model.selectedPanel!.id
        controller.handle(.minimizeSelected)
        XCTAssertTrue(model.panels.first { $0.id == selected }!.isMinimized)
        XCTAssertNotEqual(model.selectedPanel?.id, selected)
    }

    func testDismissSelectedPanel() {
        let model = WorkspaceModel.demo
        let controller = WorkspaceController(model: model)
        let selected = model.selectedPanel!.id
        controller.handle(.dismissSelected)
        XCTAssertFalse(model.panels.contains { $0.id == selected })
        XCTAssertNotNil(model.selectedPanel)
    }

    func testPointingRaisesSelectedPanel() {
        let model = WorkspaceModel.demo
        let controller = WorkspaceController(model: model)
        let target = model.panels[1]
        controller.handle(.pointerMoved(Point(x: target.frame.x + 0.02, y: target.frame.y + 0.02)))
        XCTAssertEqual(model.selectedPanel?.id, target.id)
        XCTAssertEqual(model.selectedPanel?.zIndex, model.panels.map(\.zIndex).max())
    }
}
