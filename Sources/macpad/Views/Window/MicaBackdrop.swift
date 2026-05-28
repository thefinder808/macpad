import SwiftUI
import AppKit

// macOS analog of Win11 Mica Alt: an NSVisualEffectView with
// `.windowBackground` material (sample-once, opaque-feeling, tints with
// system appearance — closest match to Mica's behavior) plus an 8-10%
// `controlAccentColor` overlay to approximate Mica's wallpaper-pickup
// tint (which macOS materials don't literally do).
struct MicaBackdrop: View {
    let isDark: Bool

    var body: some View {
        ZStack {
            VisualEffectView(material: .windowBackground, blendingMode: .behindWindow)
            Color.accentColor
                .opacity(isDark ? Dim.micaAccentTintDark : Dim.micaAccentTintLight)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
