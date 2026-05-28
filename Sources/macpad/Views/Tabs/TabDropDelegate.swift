import SwiftUI
import UniformTypeIdentifiers

// Receives a drop on a target tab. Reads the source tab's UUID from the
// drop payload, finds its current index, and asks the book to reorder.
// Win11's tab drag has an animated insertion-point indicator; we'll add
// that in a polish pass — for v1 reorder happens on release.
struct TabDropDelegate: DropDelegate {
    let target: TabState
    let book: TabBookViewModel

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let str = value as? String,
                  let sourceID = UUID(uuidString: str),
                  let from = book.tabs.firstIndex(where: { $0.id == sourceID }),
                  let to   = book.tabs.firstIndex(where: { $0.id == target.id }),
                  from != to else { return }
            DispatchQueue.main.async {
                book.reorder(from: from, to: to)
            }
        }
        return true
    }
}
