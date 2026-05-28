import AppKit
import UniformTypeIdentifiers

// File read/write with BOM-aware encoding detection and EOL detection.
// Phase 10 will broaden the encoding set and add round-tripping; this
// keeps the surface tight enough to wire ⌘O / ⌘S now.
enum DocumentIO {

    struct ReadResult {
        let text: String
        let encoding: TextEncoding
        let lineEnding: LineEnding
    }

    enum IOError: Error, LocalizedError {
        case decodingFailed(URL, TextEncoding)
        case writeFailed(URL, Error)

        var errorDescription: String? {
            switch self {
            case .decodingFailed(let url, let enc):
                return "Couldn’t decode \(url.lastPathComponent) as \(enc.displayName)."
            case .writeFailed(let url, let underlying):
                return "Couldn’t save to \(url.lastPathComponent): \(underlying.localizedDescription)"
            }
        }
    }

    // MARK: - Panels

    static func runOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .plainText, .sourceCode, .utf8PlainText, .utf16PlainText]
        panel.allowsOtherFileTypes = true       // be permissive — any text-shaped file
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func runSavePanel(suggesting fileURL: URL?, defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        if let fileURL {
            panel.directoryURL = fileURL.deletingLastPathComponent()
            panel.nameFieldStringValue = fileURL.lastPathComponent
        } else {
            panel.nameFieldStringValue = "\(defaultName).txt"
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: - Read

    static func read(from url: URL) throws -> ReadResult {
        let data = try Data(contentsOf: url)
        let (encoding, payload) = sniffEncoding(data)
        guard let text = String(data: payload, encoding: encoding.cocoaEncoding) else {
            throw IOError.decodingFailed(url, encoding)
        }
        let lineEnding = detectLineEnding(text)
        return ReadResult(text: text, encoding: encoding, lineEnding: lineEnding)
    }

    // Inspect leading bytes for a BOM; fall back to UTF-8 (the dominant
    // default for modern text files; matches Win11 Notepad's default).
    private static func sniffEncoding(_ data: Data) -> (TextEncoding, Data) {
        let utf8BOM:    [UInt8] = [0xEF, 0xBB, 0xBF]
        let utf16LEBOM: [UInt8] = [0xFF, 0xFE]
        let utf16BEBOM: [UInt8] = [0xFE, 0xFF]

        if hasPrefix(data, utf8BOM) {
            return (.utf8WithBOM, data.subdata(in: utf8BOM.count..<data.count))
        }
        if hasPrefix(data, utf16LEBOM) {
            return (.utf16LE, data.subdata(in: utf16LEBOM.count..<data.count))
        }
        if hasPrefix(data, utf16BEBOM) {
            return (.utf16BE, data.subdata(in: utf16BEBOM.count..<data.count))
        }
        return (.utf8, data)
    }

    private static func hasPrefix(_ data: Data, _ prefix: [UInt8]) -> Bool {
        guard data.count >= prefix.count else { return false }
        for i in 0..<prefix.count where data[i] != prefix[i] { return false }
        return true
    }

    private static func detectLineEnding(_ text: String) -> LineEnding {
        if text.range(of: "\r\n") != nil { return .crlf }
        if text.range(of: "\n")   != nil { return .lf }
        if text.range(of: "\r")   != nil { return .cr }
        return .lf      // empty / single-line — default to LF
    }

    // MARK: - Write

    static func write(text: String,
                      encoding: TextEncoding,
                      lineEnding: LineEnding,
                      to url: URL) throws {
        // Normalize whatever in-memory line endings to the requested target.
        // Phase 10 may instead preserve user-edited mixed endings — for now
        // we conform to the tab's selected EOL.
        let normalized = normalizeLineEndings(text, to: lineEnding)
        var data = Data()
        switch encoding {
        case .utf8:
            guard let body = normalized.data(using: .utf8) else {
                throw IOError.decodingFailed(url, encoding)
            }
            data = body
        case .utf8WithBOM:
            data.append(contentsOf: [0xEF, 0xBB, 0xBF])
            guard let body = normalized.data(using: .utf8) else {
                throw IOError.decodingFailed(url, encoding)
            }
            data.append(body)
        case .utf16LE:
            data.append(contentsOf: [0xFF, 0xFE])
            guard let body = normalized.data(using: .utf16LittleEndian) else {
                throw IOError.decodingFailed(url, encoding)
            }
            data.append(body)
        case .utf16BE:
            data.append(contentsOf: [0xFE, 0xFF])
            guard let body = normalized.data(using: .utf16BigEndian) else {
                throw IOError.decodingFailed(url, encoding)
            }
            data.append(body)
        case .windows1252:
            guard let body = normalized.data(using: .windowsCP1252) else {
                throw IOError.decodingFailed(url, encoding)
            }
            data = body
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw IOError.writeFailed(url, error)
        }
    }

    private static func normalizeLineEndings(_ text: String, to target: LineEnding) -> String {
        // Two-pass: collapse everything to LF, then expand to target.
        var s = text.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")
        switch target {
        case .lf:   return s
        case .crlf: return s.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr:   return s.replacingOccurrences(of: "\n", with: "\r")
        }
    }
}

extension TextEncoding {
    var cocoaEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8WithBOM: return .utf8
        case .utf16LE:            return .utf16LittleEndian
        case .utf16BE:            return .utf16BigEndian
        case .windows1252:        return .windowsCP1252
        }
    }
}
