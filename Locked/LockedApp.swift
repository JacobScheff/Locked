//
//  LockedApp.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import SwiftUI
import SwiftData

// Enable arrays to be stored in @AppStorage
extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

extension Dictionary: @retroactive RawRepresentable where Key == String, Value: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Key: Value].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return result
    }
}

@main
struct LockedApp: App {
    @StateObject private var lockScheduler = LockScheduler()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.lockedIndigo)
                .fontDesign(.rounded)
                .environmentObject(ScreenTimeManager.shared)
                .onAppear {
                    lockScheduler.start()
                    ScreenTimeManager.shared.refreshStatus()
                }
                .onDisappear { lockScheduler.stop() }
        }
    }
}
