import Foundation

enum GradescopeError: LocalizedError {
    case authenticityTokenMissing
    case invalidCredentials
    case notConnected
    case emptyAccount
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .authenticityTokenMissing:
            return "Gradescope didn’t return a login token. Try again in a moment."
        case .invalidCredentials:
            return "That Gradescope email or password didn’t work."
        case .notConnected:
            return "Connect Gradescope to refresh assignments."
        case .emptyAccount:
            return "No student courses were found on this Gradescope account."
        case .requestFailed(let message):
            return message
        }
    }
}

enum GradescopeParser {
    static func authenticityToken(in html: String) -> String? {
        if let token = HTMLSnippet.firstGroup(
            pattern: #"name\s*=\s*["']authenticity_token["'][^>]*\bvalue\s*=\s*["']([^"']+)["']"#,
            in: html,
            options: .caseInsensitive
        ) {
            return HTMLSnippet.decodeEntities(token)
        }
        if let token = HTMLSnippet.firstGroup(
            pattern: #"value\s*=\s*["']([^"']+)["'][^>]*\bname\s*=\s*["']authenticity_token["']"#,
            in: html,
            options: .caseInsensitive
        ) {
            return HTMLSnippet.decodeEntities(token)
        }
        if let token = HTMLSnippet.firstGroup(
            pattern: #"meta[^>]*name\s*=\s*["']csrf-token["'][^>]*content\s*=\s*["']([^"']+)["']"#,
            in: html,
            options: .caseInsensitive
        ) {
            return HTMLSnippet.decodeEntities(token)
        }
        return nil
    }

    static func loginFailed(in html: String) -> Bool {
        let lowered = html.lowercased()
        return lowered.contains("invalid email")
            || lowered.contains("invalid password")
            || lowered.contains("incorrect email")
            || lowered.contains("incorrect password")
    }

    static func catalog(fromAccountHTML html: String) -> (termNames: [String], courses: [ExternalCourseSnapshot]) {
        let terms = HTMLSnippet.elements(tag: "div", havingClass: "courseList--term", in: html)
        let buckets = HTMLSnippet.elements(tag: "div", havingClass: "courseList--coursesForTerm", in: html)
        var termNames: [String] = []
        var courses: [ExternalCourseSnapshot] = []

        if !terms.isEmpty, terms.count == buckets.count {
            for (term, bucket) in zip(terms, buckets) {
                let termName = HTMLSnippet.stripTags(term.inner)
                let parsed = courseBoxes(in: bucket.inner, termName: termName)
                if !parsed.isEmpty {
                    termNames.append(termName)
                    courses.append(contentsOf: parsed)
                }
            }
        } else {
            let parsed = courseBoxes(in: html, termName: nil)
            courses = parsed
            termNames = Array(Set(parsed.compactMap(\.termName))).sorted()
        }

        return (termNames, courses)
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
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ]
        self.session = URLSession(configuration: configuration)
    }

    func fetchCatalog(email: String, password: String) async throws -> ExternalCatalogSnapshot {
        try await login(email: email, password: password)
        let accountHTML = try await string(from: Self.url("/account"))
        let parsed = GradescopeParser.catalog(fromAccountHTML: accountHTML)
        if parsed.courses.isEmpty {
            if accountHTML.contains("session[password]") || accountHTML.lowercased().contains("log in") {
                throw GradescopeError.invalidCredentials
            }
            throw GradescopeError.emptyAccount
        }

        let year = GradescopeParser.termYear(from: parsed.termNames)
        var courses: [ExternalCourseSnapshot] = []
        for course in parsed.courses {
            let path = course.remoteID.contains("/") ? course.remoteID : "/courses/\(course.remoteID)"
            let html = try await string(from: Self.url(path))
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

        return ExternalCatalogSnapshot(
            provider: .gradescope,
            termNames: parsed.termNames,
            courses: courses
        )
    }

    private func login(email: String, password: String) async throws {
        let loginHTML = try await string(from: Self.url("/login"))
        guard let token = GradescopeParser.authenticityToken(in: loginHTML) else {
            throw GradescopeError.authenticityTokenMissing
        }

        var request = URLRequest(url: Self.url("/login"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.url("/login").absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = formBody([
            ("utf8", "✓"),
            ("authenticity_token", token),
            ("session[email]", email),
            ("session[password]", password),
            ("session[remember_me]", "1"),
            ("commit", "Log In"),
            ("session[remember_me_sso]", "0"),
        ])

        let (data, response) = try await session.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""
        let url = (response as? HTTPURLResponse)?.url?.absoluteString.lowercased() ?? ""
        if url.contains("login") || GradescopeParser.loginFailed(in: html) {
            throw GradescopeError.invalidCredentials
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
            throw GradescopeError.requestFailed("Gradescope returned \(code).")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func url(_ path: String) -> URL {
        if path.hasPrefix("http") { return URL(string: path)! }
        return URL(string: path, relativeTo: baseURL)!.absoluteURL
    }

    private func formBody(_ pairs: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        let encoded = pairs.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(encoded.utf8)
    }
}
