import StarkWorkspaceCore
import SwiftUI

struct WorkspaceView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(store.model.isEngaged ? 0.16 : 0.04)
                if store.model.isEngaged {
                    ForEach(store.model.panels.sorted(by: { $0.zIndex < $1.zIndex })) { panel in
                        if !panel.isMinimized {
                            panelView(panel, in: proxy.size)
                        }
                    }
                }
                AdaptiveHUD(store: store)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.model.isOverview)
        }
        .ignoresSafeArea()
    }

    private func panelView(_ panel: WorkspacePanel, in size: CGSize) -> some View {
        let frame = store.model.isOverview ? overviewFrame(panel, in: size) : panel.frame
        let selected = panel.id == store.model.selectedID
        return PanelCard(panel: panel, selected: selected)
        .frame(width: frame.width * size.width, height: frame.height * size.height)
        .position(x: (frame.x + frame.width / 2) * size.width, y: (frame.y + frame.height / 2) * size.height)
    }

    private func overviewFrame(_ panel: WorkspacePanel, in size: CGSize) -> NormalizedRect {
        guard let index = store.model.panels.firstIndex(where: { $0.id == panel.id }) else { return panel.frame }
        let column = index % 3
        let row = index / 3
        return NormalizedRect(x: 0.08 + Double(column) * 0.29,
                              y: 0.16 + Double(row) * 0.36,
                              width: 0.26, height: 0.30)
    }
}

private struct PanelCard: View {
    let panel: WorkspacePanel
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(Color.cyan).frame(width: 8, height: 8)
                Text(panel.title.uppercased()).font(.system(size: 14, weight: .semibold, design: .monospaced))
                Spacer()
                Text(panel.windowID == nil ? "NATIVE" : "MAC").font(.caption2).foregroundStyle(.cyan)
            }
            Divider().overlay(Color.cyan.opacity(0.5))
            Text(panel.detail).font(.system(size: 18, weight: .light))
            Spacer()
            Text("PINCH TO GRAB  ·  TWO FINGERS TO SCALE")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.cyan.opacity(0.75))
        }
        .padding(18)
        .foregroundStyle(.white)
        .background(.ultraThinMaterial.opacity(0.92))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Color.cyan : Color.cyan.opacity(0.28), lineWidth: selected ? 2 : 1))
        .shadow(color: Color.cyan.opacity(selected ? 0.35 : 0.08), radius: 22)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
