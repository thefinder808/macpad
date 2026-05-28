import AppKit

// Standard Win11 (and macOS) "Save changes to <name>?" prompt with three
// outcomes. Modal — synchronous return matches the natural flow of a
// close-tab gesture.
enum DirtyClosePrompt {
    enum Outcome {
        case save, discard, cancel
    }

    static func run(tabName: String) -> Outcome {
        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes to \(tabName)?"
        alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.alertStyle = .warning
        // Order intentionally matches macOS HIG: primary on the right.
        alert.addButton(withTitle: "Save")        // .alertFirstButtonReturn
        alert.addButton(withTitle: "Cancel")      // .alertSecondButtonReturn
        alert.addButton(withTitle: "Don’t Save")  // .alertThirdButtonReturn

        switch alert.runModal() {
        case .alertFirstButtonReturn:  return .save
        case .alertThirdButtonReturn:  return .discard
        default:                        return .cancel
        }
    }
}
