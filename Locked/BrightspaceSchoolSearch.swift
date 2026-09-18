import Foundation

struct BrightspaceInstitution: Identifiable, Equatable, Hashable {
    var name: String
    var host: String
    var isCustom: Bool = false

    var id: String { isCustom ? "custom:\(host)" : host }

    var website: String { "https://\(host)" }
}

enum BrightspaceInstitutionSearch {
    static let directoryURL = URL(string: "https://lms-disco.api.brightspace.com/institutions")!
    static let loginFinderURL = URL(string: "https://login-finder.d2l.com/")!

    /// Same shortcuts the official D2L login finder uses for long school names.
    private static let aliases: [String: String] = [
        "anahuac mayab": "anahuac",
        "anáhuac": "anahuac",
        "ashworth": "parent organization",
        "ashworth college": "parent organization",
        "broward college": "broward",
        "camosun college": "camosun",
        "central piedmont community college": "central piedmont",
        "conestoga college": "conestoga",
        "dcdsb": "durham cdsb",
        "lone star college": "lscs",
        "lonestar college": "lscs",
        "pace university": "paceu",
        "perry high school": "perry",
        "perry public schools": "perry",
        "rochester institue of technology": "rit",
        "rochester institute of technology": "rit",
        "san pablo colleges": "san pablo",
        "traverse city area public school": "traversecity",
        "tshwane university of technology": "tut",
        "university of southern california": "usc",
        "vidyashilp academy": "vidyashilp",
        "wentworth institute of technology": "wentworth",
        "wright state university": "wright state",
    ]

    static func resolvedQuery(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let host = BrightspaceParser.websiteHost(from: trimmed) {
            return host
        }
        let lowered = trimmed.lowercased()
        return aliases[lowered] ?? trimmed
    }

    static func search(_ raw: String) async throws -> [BrightspaceInstitution] {
        let query = resolvedQuery(from: raw)
        guard query.count >= 2 else { return [] }

        var components = URLComponents(url: directoryURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "contains", value: query)]
        guard let url = components?.url else { throw BrightspaceError.invalidHost }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.siren+json, application/json", forHTTPHeaderField: "Accept")
        request.setValue(BrightspaceConfig.safariUserAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            throw BrightspaceError.requestFailed("Couldn’t search Brightspace schools.")
        }

        let found = try parse(data)
        return ranked(found, query: raw)
    }

    static func parse(_ data: Data) throws -> [BrightspaceInstitution] {
        let document = try JSONDecoder().decode(Document.self, from: data)
        var seen = Set<String>()
        var results: [BrightspaceInstitution] = []
        for entity in document.entities ?? [] {
            guard let institution = entity.institution, seen.insert(institution.host).inserted else { continue }
            results.append(institution)
        }
        return results
    }

    static func ranked(_ institutions: [BrightspaceInstitution], query: String) -> [BrightspaceInstitution] {
        let hostHint = BrightspaceParser.websiteHost(from: query)
        var items = institutions.sorted {
            score($0, query: query, hostHint: hostHint) > score($1, query: query, hostHint: hostHint)
        }

        if let hostHint, items.contains(where: { $0.host == hostHint }) == false {
            items.insert(BrightspaceInstitution(name: "Use this website", host: hostHint, isCustom: true), at: 0)
        }
        if items.count > 8 {
            items = Array(items.prefix(8))
        }
        return items
    }

    static func suggestedSelection(in institutions: [BrightspaceInstitution], query: String) -> BrightspaceInstitution? {
        let hostHint = BrightspaceParser.websiteHost(from: query)
        if let hostHint, let match = institutions.first(where: { $0.host == hostHint }) {
            return match
        }
        let needle = resolvedQuery(from: query).lowercased()
        if let exactName = institutions.first(where: { $0.name.lowercased() == needle }) {
            return exactName
        }
        if institutions.count == 1 {
            return institutions.first
        }
        return nil
    }

    private static func score(_ institution: BrightspaceInstitution, query: String, hostHint: String?) -> Int {
        let name = institution.name.lowercased()
        let host = institution.host
        let needle = resolvedQuery(from: query).lowercased()
        var value = 0
        if let hostHint, host == hostHint { value += 120 }
        if name == needle { value += 80 }
        if name.hasPrefix(needle) { value += 40 }
        if host.contains(needle) { value += 24 }
        if name.contains(needle) { value += 12 }
        if institution.isCustom { value += 8 }
        return value
    }

    private struct Document: Decodable {
        var entities: [Entity]?
    }

    private struct Entity: Decodable {
        var properties: Properties?
        var links: [Link]?

        struct Properties: Decodable {
            var name: String?
        }

        struct Link: Decodable {
            var rel: [String]?
            var href: String?
        }

        var institution: BrightspaceInstitution? {
            let name = properties?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty,
                  let href = links?.first(where: { $0.rel?.contains("lms") == true })?.href,
                  let host = try? BrightspaceParser.normalizedHost(href)
            else { return nil }
            return BrightspaceInstitution(name: name, host: host)
        }
    }
}

extension BrightspaceParser {
    static func websiteHost(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else { return nil }
        var candidate = trimmed
        if !candidate.contains("://") {
            guard candidate.contains(".") else { return nil }
            candidate = "https://\(candidate)"
        }
        guard let url = URL(string: candidate),
              let host = url.host?.lowercased(),
              host.contains("."),
              !host.hasPrefix(".")
        else { return nil }
        return host
    }
}
