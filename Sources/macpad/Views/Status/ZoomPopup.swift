import SwiftUI

struct ZoomPopup: View {
    @ObservedObject var tab: TabState
    let theme: any AppTheme

    private static let steps: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        Menu {
            ForEach(Self.steps, id: \.self) { step in
                Button("\(Int(step * 100))%") { tab.zoom = step }
            }
            Divider()
            Button("Zoom In")    { ZoomCommands.zoomIn(tab) }
            Button("Zoom Out")   { ZoomCommands.zoomOut(tab) }
            Button("Reset Zoom") { tab.zoom = 1.0 }
        } label: {
            Text("\(Int(tab.zoom * 100))%")
        }
        .menuStyle(StatusBarMenuStyle())
        .fixedSize()
    }
}

enum ZoomCommands {
    static let steps: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    static func zoomIn(_ tab: TabState) {
        if let next = steps.first(where: { $0 > tab.zoom + 0.001 }) {
            tab.zoom = next
        }
    }

    static func zoomOut(_ tab: TabState) {
        if let next = steps.reversed().first(where: { $0 < tab.zoom - 0.001 }) {
            tab.zoom = next
        }
    }
}
