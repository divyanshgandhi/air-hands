import AppKit
import ApplicationServices
import StarkWorkspaceCore

enum PermissionState { case denied, granted }

struct SystemWindow {
    let id: String
    let title: String
    let appName: String
}

final class WindowBridge {
    var permission: PermissionState { AXIsProcessTrusted() ? .granted : .denied }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func eligibleWindows() -> [SystemWindow] {
        guard permission == .granted else { return [] }
        return NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }
            .flatMap { app in
                windows(for: app.processIdentifier).enumerated().compactMap { index, window in
                    guard let title = stringAttribute(kAXTitleAttribute, from: window), !title.isEmpty else { return nil }
                    return SystemWindow(id: "\(app.processIdentifier):\(index)", title: title,
                                        appName: app.localizedName ?? "Mac App")
                }
            }
    }

    func execute(_ command: WindowCommand) throws {
        guard permission == .granted else { return }
        let id: String
        switch command {
        case let .focus(value), let .move(value, _), let .resize(value, _): id = value
        }
        guard let (application, window) = resolve(id) else { return }

        switch command {
        case .focus:
            application.activate(options: [.activateIgnoringOtherApps])
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        case let .move(_, frame):
            set(frame: frame, on: window, position: true, size: false)
        case let .resize(_, frame):
            set(frame: frame, on: window, position: false, size: true)
        }
    }

    private func resolve(_ id: String) -> (NSRunningApplication, AXUIElement)? {
        let parts = id.split(separator: ":")
        guard parts.count == 2, let pid = Int32(parts[0]), let index = Int(parts[1]),
              let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        let windows = windows(for: pid)
        guard windows.indices.contains(index) else { return nil }
        return (app, windows[index])
    }

    private func windows(for pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows
    }

    private func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func set(frame: NormalizedRect, on window: AXUIElement, position: Bool, size: Bool) {
        guard let screen = NSScreen.main else { return }
        var point = CGPoint(x: screen.frame.minX + frame.x * screen.frame.width,
                            y: screen.frame.minY + frame.y * screen.frame.height)
        var dimensions = CGSize(width: frame.width * screen.frame.width,
                                height: frame.height * screen.frame.height)
        if position, let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if size, let value = AXValueCreate(.cgSize, &dimensions) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }
}
