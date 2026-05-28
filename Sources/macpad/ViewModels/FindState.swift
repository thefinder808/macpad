import Foundation

// Phase 4 stub — populated by Phase 9 (FindBar + FindEngine).
final class FindState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var isReplaceMode: Bool = false
    @Published var query: String = ""
    @Published var replacement: String = ""
    @Published var matchCase: Bool = false
    @Published var wholeWord: Bool = false
    @Published var useRegex: Bool = false
    @Published var wrapAround: Bool = true
    @Published var matches: [NSRange] = []
    @Published var currentMatchIndex: Int? = nil
}
