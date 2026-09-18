import Combine
import Foundation
import SwiftUI

@MainActor
final class ExternalSourceController: ObservableObject {
    static let shared = ExternalSourceController()

    @Published var gradescope = SourceConnectionState()
    @Published var brightspace = SourceConnectionState()
    @Published var isRefreshing = false
    @Published var lastReport: ExternalSyncReport?

    private let gradescopeClient = GradescopeClient()
    private let brightspaceClient = BrightspaceClient()

    private let gradescopeKey = "source.gradescope.state"
    private let brightspaceKey = "source.brightspace.state"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    var canRefreshGradescope: Bool {
        gradescope.isConnected && !gradescope.email.isEmpty
    }

    var canRefreshBrightspace: Bool {
        brightspace.isConnected && !(brightspace.host?.isEmpty ?? true)
    }

    var canRefresh: Bool {
        canRefreshGradescope || canRefreshBrightspace
    }

    private init() {
        gradescope = loadState(forKey: gradescopeKey)
        brightspace = loadState(forKey: brightspaceKey)
    }

    func connectGradescope(
        email: String,
        password: String,
        courses: [Course],
        keys: Double,
        karma: Double
    ) async throws -> (courses: [Course], keys: Double, karma: Double) {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        try SourceKeychain.savePassword(password, provider: .gradescope, email: cleaned)
        gradescope.email = cleaned
        persistGradescope()
        do {
            let result = try await refreshGradescope(courses: courses, keys: keys, karma: karma)
            gradescope.isConnected = true
            persistGradescope()
            return result
        } catch {
            SourceKeychain.deletePassword(provider: .gradescope, email: cleaned)
            gradescope.isConnected = false
            persistGradescope()
            throw error
        }
    }

    func connectBrightspace(
        auth: BrightspaceStoredAuth,
        courses: [Course],
        keys: Double,
        karma: Double
    ) async throws -> (courses: [Course], keys: Double, karma: Double) {
        let normalizedHost = try BrightspaceParser.normalizedHost(auth.host)
        var auth = auth
        auth.host = normalizedHost
        try saveBrightspaceAuth(auth)
        brightspace.host = normalizedHost
        persistBrightspace()

        do {
            let result = try await refreshBrightspace(courses: courses, keys: keys, karma: karma)
            brightspace.isConnected = true
            persistBrightspace()
            return result
        } catch {
            SourceKeychain.deletePassword(provider: .brightspace, email: normalizedHost)
            brightspace.isConnected = false
            persistBrightspace()
            throw error
        }
    }

    func refreshGradescope(
        courses: [Course],
        keys: Double,
        karma: Double
    ) async throws -> (courses: [Course], keys: Double, karma: Double) {
        isRefreshing = true
        defer { isRefreshing = false }
        await Task.yield()
        return try await syncGradescope(courses: courses, keys: keys, karma: karma)
    }

    func refreshBrightspace(
        courses: [Course],
        keys: Double,
        karma: Double
    ) async throws -> (courses: [Course], keys: Double, karma: Double) {
        isRefreshing = true
        defer { isRefreshing = false }
        await Task.yield()
        return try await syncBrightspace(courses: courses, keys: keys, karma: karma)
    }

    func refreshConnectedSources(
        courses: [Course],
        keys: Double,
        karma: Double
    ) async throws -> (courses: [Course], keys: Double, karma: Double) {
        guard canRefresh else { throw SourceRefreshError.notConnected }
        isRefreshing = true
        defer { isRefreshing = false }
        await Task.yield()

        var nextCourses = courses
        var nextKeys = keys
        var nextKarma = karma
        var errors: [String] = []
        var attempted = 0

        if canRefreshGradescope {
            attempted += 1
            do {
                let result = try await syncGradescope(courses: nextCourses, keys: nextKeys, karma: nextKarma)
                nextCourses = result.courses
                nextKeys = result.keys
                nextKarma = result.karma
            } catch {
                if !Self.isCancellation(error) {
                    errors.append("Gradescope: \(error.localizedDescription)")
                }
            }
        }
        if canRefreshBrightspace {
            attempted += 1
            do {
                let result = try await syncBrightspace(courses: nextCourses, keys: nextKeys, karma: nextKarma)
                nextCourses = result.courses
                nextKeys = result.keys
                nextKarma = result.karma
            } catch {
                if !Self.isCancellation(error) {
                    errors.append("Brightspace: \(error.localizedDescription)")
                }
            }
        }

        if errors.count == attempted {
            throw SourceRefreshError.failed(errors.joined(separator: " "))
        }
        return (nextCourses, nextKeys, nextKarma)
    }

    func disconnectGradescope() {
        SourceKeychain.deletePassword(provider: .gradescope, email: gradescope.email)
        gradescope = SourceConnectionState()
        lastReport = nil
        persistGradescope()
    }

    func disconnectBrightspace() {
        if let host = brightspace.host {
            SourceKeychain.deletePassword(provider: .brightspace, email: host)
            BrightspaceParser.clearWebCookies(for: host)
        }
        brightspace = SourceConnectionState()
        lastReport = nil
        persistBrightspace()
    }

    private func syncGradescope(
        courses: [Course],
        keys: Double,
        karma: Double
    ) async throws -> (courses: [Course], keys: Double, karma: Double) {
        guard !gradescope.email.isEmpty else { throw GradescopeError.notConnected }
        guard let password = SourceKeychain.password(provider: .gradescope, email: gradescope.email) else {
            throw GradescopeError.notConnected
        }

        gradescope.lastError = nil
        persistGradescope()

        do {
            var nextCourses = courses
            var nextKeys = keys
            var nextKarma = karma
            let catalog = try await gradescopeClient.fetchCatalog(email: gradescope.email, password: password)
            let report = CourseStore.applyExternalCatalog(
                catalog,
                courses: &nextCourses,
                keys: &nextKeys,
                karma: &nextKarma
            )
            lastReport = report
            gradescope.isConnected = true
            gradescope.lastSyncedAt = .now
            gradescope.lastTermName = catalog.termNames.first
            gradescope.lastSummary = report.summary
            gradescope.lastError = nil
            gradescope.courseCount = catalog.courses.count
            gradescope.assignmentCount = catalog.courses.reduce(0) { $0 + $1.assignments.count }
            persistGradescope()
            return (nextCourses, nextKeys, nextKarma)
        } catch {
            if !Self.isCancellation(error) {
                gradescope.lastError = error.localizedDescription
                persistGradescope()
            }
            throw error
        }
    }

    private func syncBrightspace(
        courses: [Course],
        keys: Double,
        karma: Double
    ) async throws -> (courses: [Course], keys: Double, karma: Double) {
        guard let host = brightspace.host, !host.isEmpty else { throw BrightspaceError.notConnected }
        guard var auth = loadBrightspaceAuth(host: host) else { throw BrightspaceError.notConnected }

        brightspace.lastError = nil
        persistBrightspace()

        do {
            var nextCourses = courses
            var nextKeys = keys
            var nextKarma = karma
            let result = try await brightspaceClient.fetchCatalog(host: host, auth: auth)
            auth = result.auth
            try saveBrightspaceAuth(auth)
            let report = CourseStore.applyExternalCatalog(
                result.catalog,
                courses: &nextCourses,
                keys: &nextKeys,
                karma: &nextKarma
            )
            lastReport = report
            brightspace.isConnected = true
            brightspace.host = host
            if !result.whoami.isEmpty {
                brightspace.email = result.whoami
            }
            brightspace.lastSyncedAt = .now
            brightspace.lastTermName = result.catalog.termNames.first
            brightspace.lastSummary = report.summary
            brightspace.lastError = nil
            brightspace.courseCount = result.catalog.courses.count
            brightspace.assignmentCount = result.catalog.courses.reduce(0) { $0 + $1.assignments.count }
            persistBrightspace()
            return (nextCourses, nextKeys, nextKarma)
        } catch {
            if !Self.isCancellation(error) {
                brightspace.lastError = error.localizedDescription
                persistBrightspace()
            }
            throw error
        }
    }

    private func persistGradescope() {
        persist(gradescope, forKey: gradescopeKey)
    }

    private func persistBrightspace() {
        persist(brightspace, forKey: brightspaceKey)
    }

    private func persist(_ state: SourceConnectionState, forKey key: String) {
        guard let data = try? encoder.encode(state) else { return }
        AppGroupStore.setSharedData(data, forKey: key)
    }

    private func loadState(forKey key: String) -> SourceConnectionState {
        guard let data = AppGroupStore.sharedData(forKey: key),
              let state = try? decoder.decode(SourceConnectionState.self, from: data)
        else { return SourceConnectionState() }
        return state
    }

    private func saveBrightspaceAuth(_ auth: BrightspaceStoredAuth) throws {
        let data = try encoder.encode(auth)
        let payload = String(data: data, encoding: .utf8) ?? ""
        try SourceKeychain.savePassword(payload, provider: .brightspace, email: auth.host)
    }

    private func loadBrightspaceAuth(host: String) -> BrightspaceStoredAuth? {
        guard let raw = SourceKeychain.password(provider: .brightspace, email: host),
              let data = raw.data(using: .utf8),
              let auth = try? decoder.decode(BrightspaceStoredAuth.self, from: data)
        else { return nil }
        return auth
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

enum SourceRefreshError: LocalizedError {
    case notConnected
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Connect a source to refresh assignments."
        case .failed(let message):
            return message
        }
    }
}
