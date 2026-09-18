import Foundation

/// Small HTML helpers for LMS pages. Not a general-purpose DOM.
enum HTMLSnippet {
    static func decodeEntities(_ raw: String) -> String {
        var result = raw
        let named: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&#x27;", "'"),
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        if let regex = try? NSRegularExpression(pattern: "&#(x?[0-9a-fA-F]+);") {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard
                    let fullRange = Range(match.range, in: result),
                    let valueRange = Range(match.range(at: 1), in: result)
                else { continue }
                let token = String(result[valueRange])
                let scalar: UInt32?
                if token.lowercased().hasPrefix("x") {
                    scalar = UInt32(token.dropFirst(), radix: 16)
                } else {
                    scalar = UInt32(token)
                }
                if let scalar, let character = UnicodeScalar(scalar) {
                    result.replaceSubrange(fullRange, with: String(Character(character)))
                }
            }
        }
        return result
    }

    static func stripTags(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        return decodeEntities(withoutTags)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func attribute(_ name: String, in openTag: String) -> String? {
        let pattern = #"\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*(?:"([^"]*)"|'([^']*)')"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsRange = NSRange(openTag.startIndex..., in: openTag)
        guard let match = regex.firstMatch(in: openTag, range: nsRange) else { return nil }
        for index in 1...match.numberOfRanges - 1 {
            if let range = Range(match.range(at: index), in: openTag), !range.isEmpty {
                return decodeEntities(String(openTag[range]))
            }
        }
        return nil
    }

    static func classNames(in openTag: String) -> [String] {
        (attribute("class", in: openTag) ?? "")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    static func hasClass(_ name: String, in openTag: String) -> Bool {
        classNames(in: openTag).contains(name)
    }

    static func firstGroup(pattern: String, in text: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, range: nsRange),
            match.numberOfRanges > 1,
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    static func allGroups(pattern: String, in text: String, options: NSRegularExpression.Options = []) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    /// Returns each matching element's opening tag and inner HTML, counting nested tags of the same name.
    static func elements(tag: String, havingClass className: String? = nil, in html: String) -> [(open: String, inner: String)] {
        elements(tag: tag, in: html, matching: { open in
            guard let className else { return true }
            return hasClass(className, in: open)
        })
    }

    static func elements(
        tag: String,
        in html: String,
        matching predicate: (String) -> Bool
    ) -> [(open: String, inner: String)] {
        var results: [(open: String, inner: String)] = []
        var searchStart = html.startIndex
        let openNeedle = "<\(tag)"
        let closeNeedle = "</\(tag)"

        while let openStart = html[searchStart...].range(of: openNeedle, options: .caseInsensitive) {
            let remainderAfterOpen = html[openStart.upperBound...]
            guard remainderAfterOpen.first.map({ $0.isWhitespace || $0 == ">" || $0 == "/" }) == true else {
                searchStart = openStart.upperBound
                continue
            }
            guard let tagEnd = html[openStart.upperBound...].firstIndex(of: ">") else { break }
            let afterOpen = html.index(after: tagEnd)
            let openTag = String(html[openStart.lowerBound..<afterOpen])
            let isVoid = openTag.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/>")
            if isVoid {
                if predicate(openTag) {
                    results.append((openTag, ""))
                }
                searchStart = afterOpen
                continue
            }

            var depth = 1
            var cursor = afterOpen
            var closeStart: String.Index?

            while depth > 0, cursor < html.endIndex {
                let slice = html[cursor...]
                let nextOpen = slice.range(of: openNeedle, options: .caseInsensitive)
                let nextClose = slice.range(of: closeNeedle, options: .caseInsensitive)

                if let nextOpen, (nextClose == nil || nextOpen.lowerBound < nextClose!.lowerBound) {
                    let after = html[nextOpen.upperBound...].first
                    let realOpen = after.map { $0.isWhitespace || $0 == ">" || $0 == "/" } == true
                    if !realOpen {
                        cursor = nextOpen.upperBound
                        continue
                    }
                    guard let gt = html[nextOpen.upperBound...].firstIndex(of: ">") else { break }
                    let tagText = String(html[nextOpen.lowerBound...gt])
                    if !tagText.contains("/>") {
                        depth += 1
                    }
                    cursor = html.index(after: gt)
                    continue
                }

                guard let nextClose else { break }
                depth -= 1
                if depth == 0 {
                    closeStart = nextClose.lowerBound
                }
                guard let gt = html[nextClose.upperBound...].firstIndex(of: ">") else { break }
                cursor = html.index(after: gt)
            }

            if let closeStart {
                let inner = String(html[afterOpen..<closeStart])
                if predicate(openTag) {
                    results.append((openTag, inner))
                    searchStart = cursor
                } else {
                    searchStart = afterOpen
                }
            } else if predicate(openTag) {
                results.append((openTag, String(html[afterOpen...])))
                break
            } else {
                searchStart = afterOpen
            }
        }
        return results
    }

    static func firstElement(tag: String, havingClass className: String, in html: String) -> (open: String, inner: String)? {
        elements(tag: tag, havingClass: className, in: html).first
    }

    static func firstElement(tag: String, id: String, in html: String) -> (open: String, inner: String)? {
        elements(tag: tag, in: html, matching: { attribute("id", in: $0) == id }).first
    }

    static func firstText(havingClass className: String, in html: String) -> String? {
        for tag in ["h3", "h2", "h4", "div", "span", "p"] {
            if let element = firstElement(tag: tag, havingClass: className, in: html) {
                let text = stripTags(element.inner)
                if !text.isEmpty { return text }
            }
        }
        return nil
    }
}
