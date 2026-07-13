import AppKit
import SwiftUI

struct AdaptiveHUD: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Label(store.model.status.uppercased(), systemImage: store.model.isEngaged ? "hand.raised.fill" : "hand.raised")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(.black.opacity(0.65), in: Capsule())
                        .overlay(Capsule().stroke(store.model.isEngaged ? Color.cyan : Color.white.opacity(0.25)))
                    Spacer()
                    Text(String(format: "%.0f FPS  %.0f MS   ·   ESC DISENGAGE", store.diagnostics.fps, store.diagnostics.latencyMs))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.65))
                }
                .padding(24)
                Spacer()
            }
            if store.model.isEngaged {
                Circle().stroke(Color.cyan, lineWidth: 2).frame(width: 24, height: 24)
                    .shadow(color: .cyan, radius: 9)
                    .position(x: store.model.pointer.x * (NSScreen.main?.frame.width ?? 1440),
                              y: store.model.pointer.y * (NSScreen.main?.frame.height ?? 900))
            }
        }
        .foregroundStyle(.white)
    }
}
