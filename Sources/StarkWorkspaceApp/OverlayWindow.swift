import AppKit
import SwiftUI

final class OverlayWindow: NSPanel {
    init(store: AppStore) {
        let bounds = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        super.init(contentRect: bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        contentView = NSHostingView(rootView: WorkspaceView(store: store))
        setFrame(bounds, display: true)
    }
}
