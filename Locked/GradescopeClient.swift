import Foundation
import WebKit

enum GradescopeConfig {
    static let host = "www.gradescope.com"
    static let loginURL = URL(string: "https://www.gradescope.com/login")!
    static let accountURL = URL(string: "https://www.gradescope.com/account")!
    static let safariUserAgent = BrightspaceConfig.safariUserAgent
    static let signedInProbe = """
    (function() {
      var html = document.documentElement ? document.documentElement.innerHTML : '';
      if (/session\\[(email|password)\\]/.test(html)) return false;
      if (document.querySelector('a[href="/logout"], a[href*="logout"], form[action*="logout"], .courseList, .courseList--term, a.courseBox, .courseBox')) return true;
      var text = (document.body && document.body.innerText || '').toLowerCase();
      return text.indexOf('log out') !== -1;
    })();
    """
}

enum GradescopeError: LocalizedError {
    case notConnected
    case cancelled
    case unauthorized
    case emptyAccount
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Connect Gradescope to refresh assignments."
        case .cancelled:
            return "Gradescope sign-in was cancelled."
        case .unauthorized:
            return "Gradescope sign-in expired. Open Gradescope and sign in again."
        case .emptyAccount:
            return "No student courses were found in the current Gradescope term."
        case .requestFailed(let message):
            return message
        }
    }
}

struct GradescopeStoredCookie: Codable, Equatable {
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

struct GradescopeStoredAuth: Codable, Equatable {
    var host: String
    var cookies: [GradescopeStoredCookie]
    var email: String?
}

enum GradescopeParser {
    static func cookieBelongs(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return domain == "gradescope.com" || domain.hasSuffix(".gradescope.com")
    }

    static func isGradescopeHost(_ host: String?) -> Bool {
        guard let host else { return false }
        let lowered = host.lowercased()
        return lowered == "gradescope.com" || lowered.hasSuffix(".gradescope.com")
    }

    static func isLoginURL(_ url: URL?) -> Bool {
        guard let url else { return true }
        let path = url.path.lowercased()
        return path.contains("/login")
            || path.contains("logon")
            || path.hasSuffix("/signin")
            || path.contains("/signin/")
    }

    static func hasAuthCookie(_ cookies: [HTTPCookie]) -> Bool {
        cookies.contains { cookie in
            guard cookieBelongs(cookie), !cookie.value.isEmpty else { return false }
            let name = cookie.name.lowercased()
            return name == "signed_token"
                || name.contains("remember")
                || name.contains("signed")
        }
    }

    static func session(
        from cookies: [HTTPCookie],
        currentURL: URL?,
        pageLooksSignedIn: Bool,
        force: Bool = false
    ) -> GradescopeStoredAuth? {
        guard isGradescopeHost(currentURL?.host), !isLoginURL(currentURL) else { return nil }
        let matching = cookies.filter(cookieBelongs)
        guard !matching.isEmpty else { return nil }
        guard pageLooksSignedIn || hasAuthCookie(matching) || force else { return nil }
        return GradescopeStoredAuth(
            host: GradescopeConfig.host,
            cookies: matching.map(GradescopeStoredCookie.init),
            email: nil
        )
    }

    static func looksLoggedOut(in html: String) -> Bool {
        html.contains("session[password]")
            || html.contains("session[email]")
            || html.lowercased().contains("name=\"session[email]\"")
    }

    static func accountEmail(in html: String) -> String? {
        let patterns = [
            #""email"\s*:\s*"([^"]+@[^"]+)""#,
            #"mailto:([^"'?]+@[^"'?]+)"#,
            #"type\s*=\s*["']email["'][^>]*\bvalue\s*=\s*["']([^"']+@[^"']+)["']"#,
            #"value\s*=\s*["']([^"']+@[^"']+)["'][^>]*\btype\s*=\s*["']email["']"#,
        ]
        for pattern in patterns {
            if let email = HTMLSnippet.firstGroup(pattern: pattern, in: html, options: .caseInsensitive) {
                let cleaned = HTMLSnippet.decodeEntities(email).trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.contains("@") { return cleaned }
            }
        }
        return nil
    }

    static func clearWebCookies() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            for cookie in cookies where cookieBelongs(cookie) {
                WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
            }
        }
    }

    static func catalog(fromAccountHTML html: String) -> (termNames: [String], courses: [ExternalCourseSnapshot]) {
        let terms = HTMLSnippet.elements(tag: "div", havingClass: "courseList--term", in: html)
        let buckets = HTMLSnippet.elements(tag: "div", havingClass: "courseList--coursesForTerm", in: html)

        // Gradescope lists the current term first. Ignore older terms.
        if let term = terms.first, let bucket = buckets.first {
            let termName = HTMLSnippet.stripTags(term.inner)
            return ([termName], courseBoxes(in: bucket.inner, termName: termName))
        }
        if let bucket = buckets.first {
            return ([], courseBoxes(in: bucket.inner, termName: nil))
        }
        return ([], [])
    }

    static func courseBoxes(in html: String, termName: String?) -> [ExternalCourseSnapshot] {
        HTMLSnippet.elements(tag: "a", havingClass: "courseBox", in: html).compactMap { box in
            guard let href = HTMLSnippet.attribute("href", in: box.open), !href.isEmpty else { return nil }
            let shortName = HTMLSnippet.firstText(havingClass: "courseBox--shortname", in: box.inner)
            let fullName = HTMLSnippet.firstText(havingClass: "courseBox--name", in: box.inner)
            let name = [shortName, fullName].compactMap { $0 }.first { !$0.isEmpty } ?? "Course"
            let remoteID = normalizedCourseID(from: href)
            return ExternalCourseSnapshot(
                remoteID: remoteID,
                name: shortName?.isEmpty == false ? shortName! : name,
                fullName: fullName,
                termName: termName,
                assignments: []
            )
        }
    }

    static func assignments(
        fromCourseHTML html: String,
        courseRemoteID: String,
        termYear: Int?,
        now: Date = .now
    ) -> [DraftAssignment] {
        let table = HTMLSnippet.firstElement(tag: "table", id: "assignments-student-table", in: html)
        let body = table?.inner ?? html
        var rows = HTMLSnippet.elements(tag: "tr", in: body, matching: { open in
            HTMLSnippet.attribute("role", in: open)?.lowercased() == "row"
                || HTMLSnippet.hasClass("js-submitAssignment", in: open)
        })
        if rows.isEmpty {
            rows = HTMLSnippet.elements(tag: "tr", in: body)
        }

        return rows.compactMap { row in
            parseAssignmentRow(
                inner: row.inner,
                courseRemoteID: courseRemoteID,
                termYear: termYear,
                now: now
            )
        }
    }

    struct DraftAssignment {
        var remoteID: String
        var name: String
        var releaseDate: Date?
        var dueDate: Date?
        var statusLabel: String
        var submitted: Bool
        var submissionPath: String?
        var pointsPossible: Double?
    }

    static func parseAssignmentRow(
        inner: String,
        courseRemoteID: String,
        termYear: Int?,
        now: Date
    ) -> DraftAssignment? {
        let header = HTMLSnippet.elements(tag: "th", havingClass: "table--primaryLink", in: inner).first
        guard let header else { return nil }

        let link = HTMLSnippet.elements(tag: "a", in: header.inner).first
        let button = HTMLSnippet.elements(tag: "button", in: header.inner).first
        let name = HTMLSnippet.stripTags(link?.inner ?? button?.inner ?? header.inner)
        guard !name.isEmpty else { return nil }

        let statusText = HTMLSnippet.elements(tag: "div", havingClass: "submissionStatus--text", in: inner).first
            .map { HTMLSnippet.stripTags($0.inner) }
            ?? "No Status"
        let loweredStatus = statusText.lowercased()
        if loweredStatus.contains("not released") {
            return nil
        }

        let href = link.flatMap { HTMLSnippet.attribute("href", in: $0.open) }
        let assignmentID = HTMLSnippet.attribute("data-assignment-id", in: button?.open ?? "")
            ?? assignmentID(from: href)
            ?? assignmentID(from: inner)
        let remoteID = assignmentID.map { "\(courseRemoteID)/\($0)" } ?? "\(courseRemoteID)/\(name.lowercased())"

        let releaseRaw = timeValue(className: "submissionTimeChart--releaseDate", in: inner)
        let dueRaw = timeValue(className: "submissionTimeChart--dueDate", in: inner)
        let releaseDate = LMSDateParser.parse(releaseRaw, termYear: termYear, now: now)
        let dueDate = LMSDateParser.parse(dueRaw, termYear: termYear, now: now)

        let submittedByClass = inner.contains("submissionStatus-complete")
        let submittedByLabel = ["submitted", "graded", "late"].contains(loweredStatus)
        let submittedByLink = href?.contains("/submissions/") == true
        let submitted = submittedByClass || submittedByLabel || submittedByLink

        let submissionPath: String?
        if submitted, let href, href.contains("/submissions/") {
            submissionPath = href
        } else {
            submissionPath = nil
        }

        let scoreText = HTMLSnippet.elements(tag: "div", havingClass: "submissionStatus--score", in: inner).first
            .map { HTMLSnippet.stripTags($0.inner) }
        let pointsPossible = points(fromScore: scoreText)

        return DraftAssignment(
            remoteID: remoteID,
            name: name,
            releaseDate: releaseDate,
            dueDate: dueDate,
            statusLabel: statusText,
            submitted: submitted,
            submissionPath: submissionPath,
            pointsPossible: pointsPossible
        )
    }

    static func submittedAt(fromJSON json: [String: Any]) -> Date? {
        let keys = ["created_at", "createdAt", "submitted_at", "submittedAt"]
        for key in keys {
            if let raw = json[key] as? String, let date = LMSDateParser.parse(raw) {
                return date
            }
        }
        return nil
    }

    static func submittedAt(fromBody body: String) -> Date? {
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let date = submittedAt(fromJSON: json) {
            return date
        }
        for key in ["created_at", "createdAt", "submitted_at", "submittedAt"] {
            if let raw = HTMLSnippet.firstGroup(pattern: #""\#(key)"\s*:\s*"([^"]+)""#, in: body),
               let date = LMSDateParser.parse(raw) {
                return date
            }
        }
        return nil
    }

    static func points(fromScore score: String?) -> Double? {
        guard let score else { return nil }
        if let denom = HTMLSnippet.firstGroup(pattern: #"[\d.]+\s*/\s*([\d.]+)"#, in: score) {
            return Double(denom)
        }
        return nil
    }

    static func termYear(from names: [String], now: Date = .now) -> Int? {
        for name in names {
            if let year = HTMLSnippet.firstGroup(pattern: #"(20\d{2})"#, in: name) {
                return Int(year)
            }
        }
        return Calendar.current.component(.year, from: now)
    }

    static func normalizedCourseID(from href: String) -> String {
        if let id = HTMLSnippet.firstGroup(pattern: #"/courses/(\d+)"#, in: href) {
            return id
        }
        return href.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func assignmentID(from href: String?) -> String? {
        guard let href else { return nil }
        return HTMLSnippet.firstGroup(pattern: #"/assignments/(\d+)"#, in: href)
    }

    private static func timeValue(className: String, in html: String) -> String? {
        let times = HTMLSnippet.elements(tag: "time", havingClass: className, in: html)
        guard let time = times.first else { return nil }
        if let datetime = HTMLSnippet.attribute("datetime", in: time.open), !datetime.isEmpty {
            return datetime
        }
        let text = HTMLSnippet.stripTags(time.inner)
        return text.isEmpty ? nil : text
    }
}

actor GradescopeClient {
    static let baseURL = URL(string: "https://www.gradescope.com")!

    private let session: URLSession

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
            "User-Agent": GradescopeConfig.safariUserAgent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ]
        self.session = URLSession(configuration: configuration)
    }

    func fetchCatalog(
        auth: GradescopeStoredAuth
    ) async throws -> (catalog: ExternalCatalogSnapshot, email: String) {
        guard !auth.cookies.isEmpty else { throw GradescopeError.unauthorized }
        installCookies(auth)

        let accountHTML = try await string(from: Self.url("/account"))
        if GradescopeParser.looksLoggedOut(in: accountHTML) {
            throw GradescopeError.unauthorized
        }
        let email = GradescopeParser.accountEmail(in: accountHTML)
            ?? auth.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let parsed = GradescopeParser.catalog(fromAccountHTML: accountHTML)
        if parsed.courses.isEmpty {
            throw GradescopeError.emptyAccount
        }

        let year = GradescopeParser.termYear(from: parsed.termNames)
        var courses: [ExternalCourseSnapshot] = []
        for course in parsed.courses {
            let path = course.remoteID.contains("/") ? course.remoteID : "/courses/\(course.remoteID)"
            let html = try await string(from: Self.url(path))
            if GradescopeParser.looksLoggedOut(in: html) {
                throw GradescopeError.unauthorized
            }
            let drafts = GradescopeParser.assignments(
                fromCourseHTML: html,
                courseRemoteID: course.remoteID,
                termYear: year
            )
            var snapshots: [ExternalAssignmentSnapshot] = []
            var submittedTimes: [String: Date] = [:]
            await withTaskGroup(of: (String, Date?).self) { group in
                for draft in drafts where draft.submitted {
                    guard let path = draft.submissionPath else { continue }
                    group.addTask {
                        (draft.remoteID, await self.fetchSubmittedAt(path: path))
                    }
                }
                for await (remoteID, date) in group {
                    if let date {
                        submittedTimes[remoteID] = date
                    }
                }
            }
            for draft in drafts {
                guard let dueDate = draft.dueDate else { continue }
                let release = draft.releaseDate ?? dueDate.addingTimeInterval(-7 * 86_400)
                var submittedAt: Date?
                if draft.submitted {
                    submittedAt = submittedTimes[draft.remoteID]
                    if submittedAt == nil {
                        // Never use "now" — that would punish a refresh after the due date.
                        submittedAt = dueDate
                    }
                }
                snapshots.append(
                    ExternalAssignmentSnapshot(
                        remoteID: draft.remoteID,
                        name: draft.name,
                        releaseDate: release,
                        dueDate: dueDate,
                        submittedAt: submittedAt,
                        pointsPossible: draft.pointsPossible,
                        statusLabel: draft.statusLabel
                    )
                )
            }
            var updated = course
            updated.assignments = snapshots
            courses.append(updated)
        }

        return (
            ExternalCatalogSnapshot(
                provider: .gradescope,
                termNames: parsed.termNames,
                courses: courses
            ),
            email
        )
    }

    private func installCookies(_ auth: GradescopeStoredAuth) {
        guard let storage = session.configuration.httpCookieStorage else { return }
        for cookie in auth.cookies.compactMap(\.httpCookie) {
            storage.setCookie(cookie)
        }
    }

    private func fetchSubmittedAt(path: String) async -> Date? {
        do {
            var request = URLRequest(url: Self.url(path))
            request.setValue("application/json, text/javascript, */*;q=0.1", forHTTPHeaderField: "Accept")
            let (data, _) = try await session.data(for: request)
            let body = String(data: data, encoding: .utf8) ?? ""
            return GradescopeParser.submittedAt(fromBody: body)
        } catch {
            return nil
        }
    }

    private func string(from url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            if code == 401 || code == 403 {
                throw GradescopeError.unauthorized
            }
            throw GradescopeError.requestFailed("Gradescope returned \(code).")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func url(_ path: String) -> URL {
        if path.hasPrefix("http") { return URL(string: path)! }
        return URL(string: path, relativeTo: baseURL)!.absoluteURL
    }
}
