import Combine
import Foundation
import SwiftUI

@MainActor
final class ExternalSourceController: ObservableObject {
    static let shared = ExternalSourceController()

    @Published var gradescope = SourceConnectionState()
    @Published var isRefreshing = false
    @Published var lastReport: ExternalSyncReport?

    private let client = GradescopeClient()
    private let gradescopeKey = "source.gradescope.state"
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

    private init() {
        gradescope = loadGradescope()
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

    func refreshGradescope(
        courses: [Course],
        keys: Double,
        karma: Double
    ) async throws -> (courses: [Course], keys: Double, karma: Double) {
        guard !gradescope.email.isEmpty else { throw GradescopeError.notConnected }
        guard let password = SourceKeychain.password(provider: .gradescope, email: gradescope.email) else {
            throw GradescopeError.notConnected
        }

        isRefreshing = true
        gradescope.lastError = nil
        persistGradescope()
        defer { isRefreshing = false }

        do {
            var nextCourses = courses
            var nextKeys = keys
            var nextKarma = karma
            let catalog = try await client.fetchCatalog(email: gradescope.email, password: password)
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
            gradescope.lastError = error.localizedDescription
            persistGradescope()
            throw error
        }
    }

    func disconnectGradescope() {
        SourceKeychain.deletePassword(provider: .gradescope, email: gradescope.email)
        gradescope = SourceConnectionState()
        lastReport = nil
        persistGradescope()
    }

    private func persistGradescope() {
        guard let data = try? encoder.encode(gradescope) else { return }
        AppGroupStore.setSharedData(data, forKey: gradescopeKey)
    }

    private func loadGradescope() -> SourceConnectionState {
        guard let data = AppGroupStore.sharedData(forKey: gradescopeKey),
              let state = try? decoder.decode(SourceConnectionState.self, from: data)
        else { return SourceConnectionState() }
        return state
    }
}
