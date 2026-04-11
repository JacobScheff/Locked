//
//  ContentView.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Sort the list so the most recently opened apps show up at the top
    @Query(sort: \ScreenTime.lastOpened, order: .reverse) private var screenTimes: [ScreenTime]
    
    @AppStorage("keys") var keys: Int = 0
    @AppStorage("karma") var karma: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // MARK: - Top Stats (Karma & Keys)
                HStack(spacing: 40) {
                    VStack {
                        Text("Karma")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(karma)")
                            .font(.largeTitle)
                            .bold()
                    }
                    
                    VStack {
                        Text("Keys")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(keys)")
                            .font(.largeTitle)
                            .bold()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                
                // MARK: - App List
                List {
                    Section("Opened Apps") {
                        if screenTimes.isEmpty {
                            Text("No apps opened yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(screenTimes) { screenTime in
                                HStack {
                                    Text(screenTime.appName)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    // Handle the optional Date
                                    if let lastOpened = screenTime.lastOpened {
                                        Text(lastOpened.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Never")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ScreenTime.self, inMemory: true)
}
