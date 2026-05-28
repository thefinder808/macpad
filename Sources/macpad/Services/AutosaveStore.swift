import Foundation
import AppKit

// Disk autosave for unsaved buffers. Each tab gets a directory under
// `~/Library/Application Support/macpad/Sessions/<autosaveID>/`
// containing:
//   - content.txt  (raw bytes in the tab's encoding, BOM preserved)
//   - meta.json    (encoding, EOL, cursor, scroll, file URL, dirty flag)
// A sessions/index.json manifest tracks the ordered list + active tab so
// SessionRestore can rebuild state on launch.
//
// All writes are atomic. Crashes between content.txt and meta.json leave
// either an old-but-consistent pair or a new pair — never half-written.
enum AutosaveStore {

    struct TabMeta: Codable {
        var displayName: String
        var fileURL: URL?
        var encoding: String
        var lineEnding: String
        var cursorLocation: Int
        var selectionLength: Int
        var scrollY: CGFloat
        var isDirty: Bool
        var zoom: Double
        var savedAt: Date
    }

    struct Manifest: Codable {
        var version: Int = 1
        var tabOrder: [UUID]
        var activeTabID: UUID?
    }

    // MARK: - Paths

    static var sessionsDir: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent("macpad", isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)
    }

    static var manifestURL: URL {
        sessionsDir.appendingPathComponent("index.json")
    }

    static func tabDir(_ id: UUID) -> URL {
        sessionsDir.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    // MARK: - Writes

    static func write(tab: TabState) {
        let dir = tabDir(tab.autosaveID)
        do {
            try FileManager.default.createDirectory(at: dir,
                                                     withIntermediateDirectories: true)
            // content.txt — raw bytes per tab encoding, EOL preserved
            try writeContent(tab: tab, to: dir.appendingPathComponent("content.txt"))
            // meta.json
            try writeMeta(tab: tab, to: dir.appendingPathComponent("meta.json"))
        } catch {
            #if DEBUG
            print("[macpad] autosave failed for \(tab.displayName): \(error)")
            #endif
        }
    }

    static func writeManifest(tabs: [TabState], activeID: UUID?) {
        let manifest = Manifest(tabOrder: tabs.map(\.autosaveID),
                                activeTabID: activeID.flatMap { id in
                                    tabs.first(where: { $0.id == id })?.autosaveID
                                })
        do {
            try FileManager.default.createDirectory(at: sessionsDir,
                                                     withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[macpad] manifest write failed: \(error)")
            #endif
        }
    }

    static func removeTabDir(autosaveID: UUID) {
        try? FileManager.default.removeItem(at: tabDir(autosaveID))
    }

    private static func writeContent(tab: TabState, to url: URL) throws {
        let data = try encodeContent(text: tab.textStorage.string,
                                      encoding: tab.encoding,
                                      lineEnding: tab.lineEnding)
        try data.write(to: url, options: .atomic)
    }

    private static func writeMeta(tab: TabState, to url: URL) throws {
        let meta = TabMeta(
            displayName: tab.displayName,
            fileURL: tab.fileURL,
            encoding: tab.encoding.rawValue,
            lineEnding: tab.lineEnding.rawValue,
            cursorLocation: tab.selectedRange.location,
            selectionLength: tab.selectedRange.length,
            scrollY: tab.scrollOffset.y,
            isDirty: tab.isDirty,
            zoom: tab.zoom,
            savedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(meta)
        try data.write(to: url, options: .atomic)
    }

    private static func encodeContent(text: String,
                                       encoding: TextEncoding,
                                       lineEnding: LineEnding) throws -> Data {
        // For autosave we preserve raw content as-is in the tab's encoding.
        // EOL normalization isn't applied here — restoring should hand back
        // exactly what the user typed, including mixed endings.
        var data = Data()
        switch encoding {
        case .utf8:
            guard let body = text.data(using: .utf8) else { throw NSError(domain: "macpad.autosave", code: 1) }
            data = body
        case .utf8WithBOM:
            data.append(contentsOf: [0xEF, 0xBB, 0xBF])
            guard let body = text.data(using: .utf8) else { throw NSError(domain: "macpad.autosave", code: 1) }
            data.append(body)
        case .utf16LE:
            data.append(contentsOf: [0xFF, 0xFE])
            guard let body = text.data(using: .utf16LittleEndian) else { throw NSError(domain: "macpad.autosave", code: 1) }
            data.append(body)
        case .utf16BE:
            data.append(contentsOf: [0xFE, 0xFF])
            guard let body = text.data(using: .utf16BigEndian) else { throw NSError(domain: "macpad.autosave", code: 1) }
            data.append(body)
        case .windows1252:
            guard let body = text.data(using: .windowsCP1252) else { throw NSError(domain: "macpad.autosave", code: 1) }
            data = body
        }
        return data
    }

    // MARK: - Reads

    static func readManifest() -> Manifest? {
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }

    static func readTab(autosaveID: UUID) -> (text: String, meta: TabMeta, encoding: TextEncoding, lineEnding: LineEnding)? {
        let dir = tabDir(autosaveID)
        let contentURL = dir.appendingPathComponent("content.txt")
        let metaURL = dir.appendingPathComponent("meta.json")

        guard let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(TabMeta.self, from: metaData),
              let contentData = try? Data(contentsOf: contentURL),
              let encoding = TextEncoding(rawValue: meta.encoding),
              let lineEnding = LineEnding(rawValue: meta.lineEnding) else {
            return nil
        }

        // Strip the BOM we wrote and decode with the same encoding.
        let payload: Data
        switch encoding {
        case .utf8WithBOM where contentData.starts(with: [0xEF, 0xBB, 0xBF]):
            payload = contentData.dropFirst(3)
        case .utf16LE where contentData.starts(with: [0xFF, 0xFE]):
            payload = contentData.dropFirst(2)
        case .utf16BE where contentData.starts(with: [0xFE, 0xFF]):
            payload = contentData.dropFirst(2)
        default:
            payload = contentData
        }

        let cocoaEnc: String.Encoding = encoding.cocoaEncoding
        guard let text = String(data: payload, encoding: cocoaEnc) else { return nil }
        return (text, meta, encoding, lineEnding)
    }
}
