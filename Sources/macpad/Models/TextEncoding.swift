import Foundation

// Phase 4 stub — read/write helpers and BOM round-trip arrive in Phase 10
// alongside `DocumentIO`. Listed up front so the enum's `displayName` is
// available to the status bar.
enum TextEncoding: String, CaseIterable, Identifiable {
    case utf8
    case utf8WithBOM
    case utf16LE
    case utf16BE
    case windows1252

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .utf8:        return "UTF-8"
        case .utf8WithBOM: return "UTF-8 with BOM"
        case .utf16LE:     return "UTF-16 LE"
        case .utf16BE:     return "UTF-16 BE"
        case .windows1252: return "Windows 1252"
        }
    }
}
