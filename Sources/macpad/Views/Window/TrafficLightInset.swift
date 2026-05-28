import SwiftUI

// Kept for historical / API reference. After ContentView was reverted to
// place the tab band BELOW the system titlebar (rather than overlapping
// it), this inset is unused — the first tab starts near the window's
// leading edge because traffic lights live above the band, not beside it.
// Leaving the type in place so a future revisit of the unified-titlebar
// approach (perhaps via NSToolbar) can reuse it.
struct TrafficLightInset: View {
    var body: some View {
        Color.clear
            .frame(width: Dim.trafficLightInset, height: Dim.titleBarHeight)
    }
}
