import Foundation

// Match enumeration for the find/replace bar. Plain search uses NSString
// for speed (avoids String/Substring index gymnastics over UTF-8). Regex
// uses NSRegularExpression. Whole-word in plain mode is emulated with a
// `\b…\b` regex because NSString has no native whole-word option.
enum FindEngine {

    struct Options {
        let matchCase: Bool
        let wholeWord: Bool
        let useRegex: Bool
    }

    enum FindError: Error, LocalizedError {
        case invalidRegex(String)
        var errorDescription: String? {
            if case .invalidRegex(let p) = self { return "Invalid regex: \(p)" }
            return nil
        }
    }

    static func matches(in haystack: String,
                        query: String,
                        options: Options) throws -> [NSRange] {
        guard !query.isEmpty else { return [] }

        if options.useRegex || options.wholeWord {
            return try regexMatches(haystack: haystack, query: query, options: options)
        }
        return plainMatches(haystack: haystack, query: query, options: options)
    }

    private static func plainMatches(haystack: String,
                                     query: String,
                                     options: Options) -> [NSRange] {
        let ns = haystack as NSString
        var results: [NSRange] = []
        var searchRange = NSRange(location: 0, length: ns.length)
        let compareOpts: NSString.CompareOptions = options.matchCase ? [] : [.caseInsensitive]

        while searchRange.location < ns.length {
            let r = ns.range(of: query, options: compareOpts, range: searchRange)
            if r.location == NSNotFound { break }
            results.append(r)
            let next = r.location + max(r.length, 1)
            searchRange = NSRange(location: next, length: ns.length - next)
        }
        return results
    }

    private static func regexMatches(haystack: String,
                                     query: String,
                                     options: Options) throws -> [NSRange] {
        var pattern = options.useRegex ? query : NSRegularExpression.escapedPattern(for: query)
        if options.wholeWord {
            pattern = "\\b" + pattern + "\\b"
        }
        var flags: NSRegularExpression.Options = []
        if !options.matchCase { flags.insert(.caseInsensitive) }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: flags)
        } catch {
            throw FindError.invalidRegex(query)
        }
        let ns = haystack as NSString
        let full = NSRange(location: 0, length: ns.length)
        return regex.matches(in: haystack, options: [], range: full).map { $0.range }
    }
}
