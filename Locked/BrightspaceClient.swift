import Foundation
import WebKit

enum BrightspaceConfig {
    static let courseOfferingTypeID = 3
    static let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
}

enum BrightspaceError: LocalizedError {
    case notConnected
    case invalidHost
    case cancelled
    case emptyAccount
    case notFound
    case forbidden
    case unauthorized
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Connect Brightspace to refresh assignments."
        case .invalidHost:
            return "Enter your school’s Brightspace website, such as yourschool.brightspace.com."
        case .cancelled:
            return "Brightspace sign-in was cancelled."
        case .emptyAccount:
            return "No current Brightspace courses were found."
        case .notFound, .forbidden:
            return "Brightspace couldn’t find that item."
        case .unauthorized:
            return "Brightspace sign-in expired. Open Brightspace and sign in again."
        case .requestFailed(let message):
            return message
        }
    }

    var isAuthFailure: Bool {
        switch self {
        case .unauthorized, .notConnected, .cancelled:
            return true
        default:
            return false
        }
    }
}

struct BrightspaceStoredCookie: Codable, Equatable {
    var name: String
    var value: String
    var domain: String
    var path: String
    var expiresAt: Date?
    var isSecure: Bool

    init(_ cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        domain = cookie.domain
        path = cookie.path
        expiresAt = cookie.expiresDate
        isSecure = cookie.isSecure
    }

    var httpCookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path.isEmpty ? "/" : path,
            .secure: isSecure ? "TRUE" : "FALSE",
        ]
        if let expiresAt {
            properties[.expires] = expiresAt
        }
        return HTTPCookie(properties: properties)
    }
}

struct BrightspaceStoredAuth: Codable, Equatable {
    var host: String
    var cookies: [BrightspaceStoredCookie]
    var csrfToken: String?

    var sessionToken: String? {
        csrfToken ?? cookies.first(where: { $0.name == "d2lSessionVal" })?.value
    }
}

enum BrightspaceParser {
    static func normalizedHost(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BrightspaceError.invalidHost }
        var candidate = trimmed
        if !candidate.contains("://") {
            candidate = "https://\(candidate)"
        }
        guard let url = URL(string: candidate),
              let host = url.host,
              !host.isEmpty,
              url.scheme?.lowercased() == "https" || !trimmed.contains("://")
        else {
            throw BrightspaceError.invalidHost
        }
        return host.lowercased()
    }

    static func termName(from start: Date?, now: Date = .now) -> String {
        let date = start ?? now
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        switch calendar.component(.month, from: date) {
        case 1...5: return "Spring \(year)"
        case 6...7: return "Summer \(year)"
        default: return "Fall \(year)"
        }
    }

    static func displayName(code: String?, name: String) -> String {
        if let code {
            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return name
    }

    static func isCurrentCourse(access: BrightspaceAccess, now: Date = .now) -> Bool {
        guard access.isActive, access.canAccess != false else { return false }
        if let start = LMSDateParser.parse(access.startDate), now < start { return false }
        if let end = LMSDateParser.parse(access.endDate), now > end { return false }
        return true
    }

    static func earliestSubmissionDate(in entities: [BrightspaceEntityDropbox]) -> Date? {
        let dates = entities
            .flatMap(\.submissionDates)
            .compactMap { LMSDateParser.parse($0) }
            .sorted()
        return dates.first
    }

    static func isSubmitted(_ entities: [BrightspaceEntityDropbox]) -> Bool {
        entities.contains { entity in
            !entity.submissions.isEmpty || entity.completionDate != nil
        }
    }

    static func homeURL(for host: String) -> URL {
        URL(string: "https://\(host)/d2l/home")!
    }

    static func cookieBelongs(_ cookie: HTTPCookie, host: String) -> Bool {
        let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let campus = host.lowercased()
        return campus == domain
            || campus.hasSuffix(".\(domain)")
            || domain.hasSuffix(".\(campus)")
            || domain.contains("brightspace")
    }

    static func isLoginURL(_ url: URL?) -> Bool {
        guard let url else { return true }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        let combined = "\(host)\(path)\(url.absoluteString.lowercased())"
        return path.contains("/login")
            || path.contains("logon")
            || path.contains("signin")
            || combined.contains("/sso")
            || combined.contains("saml")
            || combined.contains("shibboleth")
            || combined.contains("login.microsoftonline")
            || combined.contains("idp.")
    }

    static func isCampusURL(_ url: URL?, host: String) -> Bool {
        guard let urlHost = url?.host?.lowercased() else { return false }
        return urlHost == host.lowercased() || urlHost.hasSuffix(".\(host.lowercased())")
    }

    static func session(from cookies: [HTTPCookie], host: String, currentURL: URL?) -> BrightspaceStoredAuth? {
        let matching = cookies.filter { cookieBelongs($0, host: host) }
        guard let csrf = matching.first(where: { $0.name == "d2lSessionVal" })?.value, !csrf.isEmpty else {
            return nil
        }
        guard isCampusURL(currentURL, host: host), !isLoginURL(currentURL) else { return nil }
        let path = currentURL?.path.lowercased() ?? ""
        guard path.hasPrefix("/d2l/") else { return nil }
        return BrightspaceStoredAuth(
            host: host,
            cookies: matching.map(BrightspaceStoredCookie.init),
            csrfToken: csrf
        )
    }

    static func clearWebCookies(for host: String) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            for cookie in cookies where cookieBelongs(cookie, host: host) {
                WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
            }
        }
    }
}

struct BrightspacePaged<Item: Decodable>: Decodable {
    let items: [Item]
    let pagingInfo: BrightspacePagingInfo?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case pagingInfo = "PagingInfo"
    }
}

struct BrightspacePagingInfo: Decodable {
    let bookmark: String?
    let hasMoreItems: Bool?

    enum CodingKeys: String, CodingKey {
        case bookmark = "Bookmark"
        case hasMoreItems = "HasMoreItems"
    }
}

struct BrightspaceEnrollment: Decodable {
    let orgUnit: BrightspaceOrgUnit
    let access: BrightspaceAccess

    enum CodingKeys: String, CodingKey {
        case orgUnit = "OrgUnit"
        case access = "Access"
    }
}

struct BrightspaceOrgUnit: Decodable {
    let id: Int
    let name: String
    let code: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case code = "Code"
    }
}

struct BrightspaceAccess: Decodable {
    let isActive: Bool
    let canAccess: Bool?
    let startDate: String?
    let endDate: String?

    enum CodingKeys: String, CodingKey {
        case isActive = "IsActive"
        case canAccess = "CanAccess"
        case startDate = "StartDate"
        case endDate = "EndDate"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        canAccess = try container.decodeIfPresent(Bool.self, forKey: .canAccess)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
    }
}

struct BrightspaceFolder: Decodable {
    let id: Int
    let name: String
    let dueDate: String?
    let startDate: String?
    let isHidden: Bool?
    let availability: Availability?
    let assessment: Assessment?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case dueDate = "DueDate"
        case startDate = "StartDate"
        case isHidden = "IsHidden"
        case availability = "Availability"
        case assessment = "Assessment"
    }

    struct Availability: Decodable {
        let startDate: String?

        enum CodingKeys: String, CodingKey {
            case startDate = "StartDate"
        }
    }

    struct Assessment: Decodable {
        let scoreDenominator: Double?

        enum CodingKeys: String, CodingKey {
            case scoreDenominator = "ScoreDenominator"
        }
    }

    var releaseRaw: String? { startDate ?? availability?.startDate }
}

struct BrightspaceEntityDropbox: Decodable {
    let submissions: [BrightspaceUserSubmission]
    let completionDate: String?

    enum CodingKeys: String, CodingKey {
        case submissions = "Submissions"
        case completionDate = "CompletionDate"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        submissions = try container.decodeIfPresent([BrightspaceUserSubmission].self, forKey: .submissions) ?? []
        completionDate = try container.decodeIfPresent(String.self, forKey: .completionDate)
    }

    var submissionDates: [String] {
        submissions.compactMap(\.timestamp) + [completionDate].compactMap { $0 }
    }
}

struct BrightspaceUserSubmission: Decodable {
    let date: String?
    let submissionDate: String?

    enum CodingKeys: String, CodingKey {
        case date = "Date"
        case submissionDate = "SubmissionDate"
    }

    var timestamp: String? { submissionDate ?? date }
}

struct BrightspaceWhoami: Decodable {
    let uniqueName: String?
    let displayName: String?
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case uniqueName = "UniqueName"
        case displayName = "DisplayName"
        case firstName = "FirstName"
        case lastName = "LastName"
    }

    var display: String {
        if let uniqueName, !uniqueName.isEmpty { return uniqueName }
        if let displayName, !displayName.isEmpty { return displayName }
        let combined = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        return combined
    }
}

struct BrightspaceProductVersion: Decodable {
    let productCode: String
    let latestVersion: String

    enum CodingKeys: String, CodingKey {
        case productCode = "ProductCode"
        case latestVersion = "LatestVersion"
    }
}

actor BrightspaceClient {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private var workingAuth: BrightspaceStoredAuth?

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 30
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": BrightspaceConfig.safariUserAgent,
        ]
        self.session = URLSession(configuration: configuration)
    }

    func fetchCatalog(
        host: String,
        auth: BrightspaceStoredAuth
    ) async throws -> (catalog: ExternalCatalogSnapshot, auth: BrightspaceStoredAuth, whoami: String) {
        workingAuth = try await validAuth(auth)
        installCookies(auth)
        defer { workingAuth = nil }

        let versions = try await productVersions(host: host)
        let lp = versions["lp"] ?? "1.46"
        let le = versions["le"] ?? "1.74"

        let whoami: BrightspaceWhoami = try await getJSON(
            from: apiURL(host: host, path: "/d2l/api/lp/\(lp)/users/whoami"),
            sessionRequired: true
        )

        let enrollments = try await fetchEnrollments(host: host, lp: lp)
        let active = enrollments.filter { BrightspaceParser.isCurrentCourse(access: $0.access) }
        if active.isEmpty {
            throw BrightspaceError.emptyAccount
        }

        var courses: [ExternalCourseSnapshot] = []
        var termNames: [String] = []
        try await withThrowingTaskGroup(of: (ExternalCourseSnapshot, String).self) { group in
            for enrollment in active {
                group.addTask {
                    let snapshot = try await self.fetchCourse(enrollment, host: host, le: le)
                    let term = BrightspaceParser.termName(
                        from: LMSDateParser.parse(enrollment.access.startDate)
                    )
                    return (snapshot, term)
                }
            }
            for try await (snapshot, term) in group {
                courses.append(snapshot)
                if !termNames.contains(term) {
                    termNames.append(term)
                }
            }
        }

        courses.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (
            ExternalCatalogSnapshot(provider: .brightspace, termNames: termNames, courses: courses),
            workingAuth ?? auth,
            whoami.display
        )
    }

    private func fetchCourse(
        _ enrollment: BrightspaceEnrollment,
        host: String,
        le: String
    ) async throws -> ExternalCourseSnapshot {
        let course = enrollment.orgUnit
        let remoteID = "\(course.id)"
        let name = BrightspaceParser.displayName(code: course.code, name: course.name)
        let folders: [BrightspaceFolder]
        do {
            folders = try await getJSON(
                from: apiURL(host: host, path: "/d2l/api/le/\(le)/\(course.id)/dropbox/folders/")
            )
        } catch let error as BrightspaceError where error.isAuthFailure {
            throw error
        } catch {
            return ExternalCourseSnapshot(
                remoteID: remoteID,
                name: name,
                fullName: course.name,
                termName: BrightspaceParser.termName(from: LMSDateParser.parse(enrollment.access.startDate)),
                assignments: []
            )
        }

        var assignments: [ExternalAssignmentSnapshot] = []
        for folder in folders {
            guard folder.isHidden != true else { continue }
            let folderName = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !folderName.isEmpty, let dueDate = LMSDateParser.parse(folder.dueDate) else { continue }

            let submissions: [BrightspaceEntityDropbox]
            do {
                submissions = try await getJSON(
                    from: apiURL(
                        host: host,
                        path: "/d2l/api/le/\(le)/\(course.id)/dropbox/folders/\(folder.id)/submissions/mysubmissions/"
                    ),
                    allowMissing: true
                )
            } catch let error as BrightspaceError where error.isAuthFailure {
                throw error
            } catch {
                submissions = []
            }

            let submitted = BrightspaceParser.isSubmitted(submissions)
            var submittedAt: Date?
            if submitted {
                submittedAt = BrightspaceParser.earliestSubmissionDate(in: submissions) ?? dueDate
            }
            let release = LMSDateParser.parse(folder.releaseRaw) ?? dueDate.addingTimeInterval(-7 * 86_400)
            assignments.append(
                ExternalAssignmentSnapshot(
                    remoteID: "\(remoteID)/\(folder.id)",
                    name: folderName,
                    releaseDate: release,
                    dueDate: dueDate,
                    submittedAt: submittedAt,
                    pointsPossible: folder.assessment?.scoreDenominator,
                    statusLabel: submitted ? "Submitted" : "No Status"
                )
            )
        }

        return ExternalCourseSnapshot(
            remoteID: remoteID,
            name: name,
            fullName: course.name,
            termName: BrightspaceParser.termName(from: LMSDateParser.parse(enrollment.access.startDate)),
            assignments: assignments
        )
    }

    private func fetchEnrollments(host: String, lp: String) async throws -> [BrightspaceEnrollment] {
        let now = ISO8601DateFormatter().string(from: Date())
        let filtered: [URLQueryItem] = [
            URLQueryItem(name: "orgUnitTypeId", value: "\(BrightspaceConfig.courseOfferingTypeID)"),
            URLQueryItem(name: "isActive", value: "true"),
            URLQueryItem(name: "canAccess", value: "true"),
            URLQueryItem(name: "startDateTime", value: now),
            URLQueryItem(name: "endDateTime", value: now),
        ]
        do {
            let items = try await fetchEnrollmentPages(host: host, lp: lp, query: filtered)
            if !items.isEmpty { return items }
        } catch let error as BrightspaceError {
            switch error {
            case .requestFailed, .notFound:
                break
            default:
                throw error
            }
        }
        let fallback = [URLQueryItem(name: "orgUnitTypeId", value: "\(BrightspaceConfig.courseOfferingTypeID)")]
        return try await fetchEnrollmentPages(host: host, lp: lp, query: fallback)
    }

    private func fetchEnrollmentPages(
        host: String,
        lp: String,
        query: [URLQueryItem]
    ) async throws -> [BrightspaceEnrollment] {
        var items: [BrightspaceEnrollment] = []
        var bookmark: String?
        var seen = Set<String>()
        repeat {
            var itemsQuery = query
            if let bookmark, !bookmark.isEmpty {
                itemsQuery.append(URLQueryItem(name: "bookmark", value: bookmark))
            }
            let page: BrightspacePaged<BrightspaceEnrollment> = try await getJSON(
                from: apiURL(host: host, path: "/d2l/api/lp/\(lp)/enrollments/myenrollments/", query: itemsQuery),
                sessionRequired: true
            )
            items.append(contentsOf: page.items)
            let next = page.pagingInfo?.bookmark
            if page.pagingInfo?.hasMoreItems == true, let next, !next.isEmpty, seen.insert(next).inserted {
                bookmark = next
            } else {
                bookmark = nil
            }
        } while bookmark != nil
        return items
    }

    private func productVersions(host: String) async throws -> [String: String] {
        do {
            let versions: [BrightspaceProductVersion] = try await getJSON(
                from: apiURL(host: host, path: "/d2l/api/versions/")
            )
            var map: [String: String] = [:]
            for version in versions {
                map[version.productCode.lowercased()] = version.latestVersion
            }
            return map
        } catch {
            return ["lp": "1.46", "le": "1.74"]
        }
    }

    private func validAuth(_ auth: BrightspaceStoredAuth) async throws -> BrightspaceStoredAuth {
        guard auth.sessionToken != nil, !auth.cookies.isEmpty else {
            throw BrightspaceError.unauthorized
        }
        return auth
    }

    private func installCookies(_ auth: BrightspaceStoredAuth) {
        guard let storage = session.configuration.httpCookieStorage else { return }
        for cookie in auth.cookies.compactMap(\.httpCookie) {
            storage.setCookie(cookie)
        }
    }

    private func getJSON<T: Decodable>(
        from url: URL,
        allowMissing: Bool = false,
        sessionRequired: Bool = false
    ) async throws -> T {
        guard let auth = workingAuth else { throw BrightspaceError.notConnected }
        return try await sendJSON(
            T.self,
            url: url,
            auth: auth,
            allowMissing: allowMissing,
            sessionRequired: sessionRequired
        )
    }

    private func sendJSON<T: Decodable>(
        _ type: T.Type,
        url: URL,
        auth: BrightspaceStoredAuth,
        allowMissing: Bool,
        sessionRequired: Bool,
        attempt: Int = 0
    ) async throws -> T {
        var request = URLRequest(url: url)
        if let csrf = auth.sessionToken {
            request.setValue(csrf, forHTTPHeaderField: "X-Csrf-Token")
        }
        request.setValue("https://\(auth.host)/d2l/home", forHTTPHeaderField: "Referer")
        request.setValue("https://\(auth.host)", forHTTPHeaderField: "Origin")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1

        if code == 429, attempt < 3 {
            let delay = UInt64(pow(2.0, Double(attempt))) * 400_000_000
            try await Task.sleep(nanoseconds: delay)
            return try await sendJSON(
                type,
                url: url,
                auth: auth,
                allowMissing: allowMissing,
                sessionRequired: sessionRequired,
                attempt: attempt + 1
            )
        }
        if code == 401 || (sessionRequired && code == 403) { throw BrightspaceError.unauthorized }
        if code == 403 { throw BrightspaceError.forbidden }
        if code == 404 {
            if allowMissing, let empty = emptyJSON(type) { return empty }
            throw BrightspaceError.notFound
        }
        guard (200..<300).contains(code) else {
            throw BrightspaceError.requestFailed("Brightspace returned \(code).")
        }
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           text.hasPrefix("<") {
            throw BrightspaceError.unauthorized
        }
        return try decoder.decode(T.self, from: data)
    }

    private func emptyJSON<T>(_ type: T.Type) -> T? {
        if type == [BrightspaceEntityDropbox].self {
            return ([BrightspaceEntityDropbox]() as! T)
        }
        if type == [BrightspaceFolder].self {
            return ([BrightspaceFolder]() as! T)
        }
        return nil
    }

    private func apiURL(host: String, path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        if !query.isEmpty {
            components.queryItems = query
        }
        return components.url!
    }
}
