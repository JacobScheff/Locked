import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum BrightspaceConfig {
    /// Register Locked in Brightspace Manage Extensibility → OAuth 2.0 (authorization grant).
    /// Redirect URI must be exactly `locked://oauth2callback`.
    static let clientID = ""
    static let clientSecret = ""

    static let callbackScheme = "locked"
    static let redirectURI = "locked://oauth2callback"
    static let scope = "core:*:* enrollment:own_enrollment:read dropbox:folders:read"
    static let authorizationURL = URL(string: "https://auth.brightspace.com/oauth2/auth")!
    static let tokenURL = URL(string: "https://auth.brightspace.com/core/connect/token")!
    static let courseOfferingTypeID = 3

    static var isConfigured: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum BrightspaceError: LocalizedError {
    case notConnected
    case invalidHost
    case missingClientID
    case authUnavailable
    case cancelled
    case invalidCallback
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
            return "Enter a Brightspace address like brightspace.usc.edu."
        case .missingClientID:
            return "Brightspace needs an OAuth client ID from your school’s Manage Extensibility page."
        case .authUnavailable:
            return "Couldn’t open Brightspace sign-in. Try again."
        case .cancelled:
            return "Brightspace sign-in was cancelled."
        case .invalidCallback:
            return "Brightspace didn’t return a sign-in code."
        case .emptyAccount:
            return "No current Brightspace courses were found."
        case .notFound, .forbidden:
            return "Brightspace couldn’t find that item."
        case .unauthorized:
            return "Brightspace sign-in expired. Connect again."
        case .requestFailed(let message):
            return message
        }
    }

    var isAuthFailure: Bool {
        switch self {
        case .unauthorized, .notConnected, .cancelled, .invalidCallback:
            return true
        default:
            return false
        }
    }
}

struct BrightspaceStoredAuth: Codable, Equatable {
    var host: String
    var clientID: String
    var clientSecret: String?
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
}

struct BrightspaceAuthCode: Sendable {
    let code: String
    let verifier: String
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
        let dates = entities.flatMap(\.submissionDates).compactMap(LMSDateParser.parse).sorted()
        return dates.first
    }

    static func isSubmitted(_ entities: [BrightspaceEntityDropbox]) -> Bool {
        entities.contains { entity in
            !entity.submissions.isEmpty || entity.completionDate != nil
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

private struct BrightspaceTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Double?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
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
        configuration.timeoutIntervalForRequest = 30
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "Locked/1.0",
        ]
        self.session = URLSession(configuration: configuration)
    }

    func exchangeCode(
        _ code: String,
        verifier: String,
        clientID: String,
        clientSecret: String?
    ) async throws -> BrightspaceTokens {
        var pairs: [(String, String)] = [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", BrightspaceConfig.redirectURI),
            ("client_id", clientID),
            ("code_verifier", verifier),
        ]
        if let clientSecret, !clientSecret.isEmpty {
            pairs.append(("client_secret", clientSecret))
        }
        return try await requestTokens(pairs: pairs)
    }

    func fetchCatalog(
        host: String,
        auth: BrightspaceStoredAuth
    ) async throws -> (catalog: ExternalCatalogSnapshot, auth: BrightspaceStoredAuth, whoami: String) {
        workingAuth = try await validAuth(auth)
        defer { workingAuth = nil }

        let versions = try await productVersions(host: host)
        let lp = versions["lp"] ?? "1.46"
        let le = versions["le"] ?? "1.74"

        let whoami: BrightspaceWhoami = try await getJSON(
            from: apiURL(host: host, path: "/d2l/api/lp/\(lp)/users/whoami")
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
                from: apiURL(host: host, path: "/d2l/api/lp/\(lp)/enrollments/myenrollments/", query: itemsQuery)
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
        var auth = auth
        if let expiry = auth.expiresAt, expiry.addingTimeInterval(-60) > .now {
            return auth
        }
        if auth.refreshToken != nil {
            do {
                let tokens = try await refreshTokens(auth)
                auth.accessToken = tokens.accessToken
                auth.refreshToken = tokens.refreshToken ?? auth.refreshToken
                auth.expiresAt = tokens.expiresAt
                return auth
            } catch {
                if auth.expiresAt == nil { return auth }
                throw BrightspaceError.unauthorized
            }
        }
        return auth
    }

    private func refreshTokens(_ auth: BrightspaceStoredAuth) async throws -> BrightspaceTokens {
        guard let refreshToken = auth.refreshToken, !refreshToken.isEmpty else {
            throw BrightspaceError.unauthorized
        }
        var pairs: [(String, String)] = [
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", auth.clientID),
        ]
        if let secret = auth.clientSecret, !secret.isEmpty {
            pairs.append(("client_secret", secret))
        }
        return try await requestTokens(pairs: pairs)
    }

    private func requestTokens(pairs: [(String, String)]) async throws -> BrightspaceTokens {
        var request = URLRequest(url: BrightspaceConfig.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(pairs)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BrightspaceError.requestFailed("Brightspace token exchange returned \(code).")
        }
        let payload = try decoder.decode(BrightspaceTokenResponse.self, from: data)
        let expiry = payload.expiresIn.map { Date.now.addingTimeInterval($0) }
        return BrightspaceTokens(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            expiresAt: expiry
        )
    }

    private func getJSON<T: Decodable>(
        from url: URL,
        allowMissing: Bool = false
    ) async throws -> T {
        guard var auth = workingAuth else { throw BrightspaceError.notConnected }
        auth = try await validAuth(auth)
        workingAuth = auth
        do {
            return try await sendJSON(T.self, url: url, token: auth.accessToken, allowMissing: allowMissing)
        } catch BrightspaceError.unauthorized {
            let tokens = try await refreshTokens(auth)
            auth.accessToken = tokens.accessToken
            auth.refreshToken = tokens.refreshToken ?? auth.refreshToken
            auth.expiresAt = tokens.expiresAt
            workingAuth = auth
            return try await sendJSON(T.self, url: url, token: auth.accessToken, allowMissing: allowMissing)
        }
    }

    private func sendJSON<T: Decodable>(
        _ type: T.Type,
        url: URL,
        token: String,
        allowMissing: Bool,
        attempt: Int = 0
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1

        if code == 429, attempt < 3 {
            let delay = UInt64(pow(2.0, Double(attempt))) * 400_000_000
            try await Task.sleep(nanoseconds: delay)
            return try await sendJSON(type, url: url, token: token, allowMissing: allowMissing, attempt: attempt + 1)
        }
        if code == 401 { throw BrightspaceError.unauthorized }
        if code == 403 { throw BrightspaceError.forbidden }
        if code == 404 {
            if allowMissing, let empty = emptyJSON(type) { return empty }
            throw BrightspaceError.notFound
        }
        guard (200..<300).contains(code) else {
            throw BrightspaceError.requestFailed("Brightspace returned \(code).")
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

    private func formBody(_ pairs: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*~")
        let encoded = pairs.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(encoded.utf8)
    }
}

struct BrightspaceTokens: Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
}

@MainActor
final class BrightspaceAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func signIn(clientID: String) async throws -> BrightspaceAuthCode {
        let trimmed = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BrightspaceError.missingClientID }

        let verifier = BrightspaceOAuth.makeVerifier()
        let challenge = BrightspaceOAuth.makeChallenge(for: verifier)
        let state = BrightspaceOAuth.makeVerifier()

        var components = URLComponents(url: BrightspaceConfig.authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: trimmed),
            URLQueryItem(name: "redirect_uri", value: BrightspaceConfig.redirectURI),
            URLQueryItem(name: "scope", value: BrightspaceConfig.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else { throw BrightspaceError.authUnavailable }

        return try await withCheckedThrowingContinuation { continuation in
            var settled = false
            let finish: (Result<BrightspaceAuthCode, Error>) -> Void = { result in
                guard !settled else { return }
                settled = true
                self.session = nil
                continuation.resume(with: result)
            }

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: BrightspaceConfig.callbackScheme
            ) { callbackURL, error in
                if let error {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    finish(.failure(cancelled ? BrightspaceError.cancelled : error))
                    return
                }
                guard let callbackURL,
                      let parts = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = parts.queryItems?.first(where: { $0.name == "code" })?.value,
                      !code.isEmpty
                else {
                    finish(.failure(BrightspaceError.invalidCallback))
                    return
                }
                let returnedState = parts.queryItems?.first(where: { $0.name == "state" })?.value
                if returnedState != nil && returnedState != state {
                    finish(.failure(BrightspaceError.invalidCallback))
                    return
                }
                finish(.success(BrightspaceAuthCode(code: code, verifier: verifier)))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                finish(.failure(BrightspaceError.authUnavailable))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        return scenes.first?.windows.first ?? ASPresentationAnchor()
    }
}

private enum BrightspaceOAuth {
    static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    static func makeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
