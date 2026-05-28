import Foundation

// Phase 4 stub — detection and rewriting arrive in Phase 10.
enum LineEnding: String, CaseIterable, Identifiable {
    case lf   = "\n"
    case crlf = "\r\n"
    case cr   = "\r"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lf:   return "LF"
        case .crlf: return "CRLF"
        case .cr:   return "CR"
        }
    }

    var verboseName: String {
        switch self {
        case .lf:   return "Unix (LF)"
        case .crlf: return "Windows (CRLF)"
        case .cr:   return "Classic Mac (CR)"
        }
    }
}
