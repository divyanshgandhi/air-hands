import Foundation

public struct NormalizedRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct WorkspacePanel: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var frame: NormalizedRect
    public var zIndex: Int
    public var isMinimized: Bool
    public var windowID: String?

    public init(id: UUID = UUID(), title: String, detail: String, frame: NormalizedRect,
                zIndex: Int = 0, isMinimized: Bool = false, windowID: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.frame = frame
        self.zIndex = zIndex
        self.isMinimized = isMinimized
        self.windowID = windowID
    }
}

public enum WindowCommand: Equatable, Sendable {
    case focus(String)
    case move(String, NormalizedRect)
    case resize(String, NormalizedRect)
}
