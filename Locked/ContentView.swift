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
    
    // Updated to sort by totalScreenTime (highest time at the top)
    @Query(sort: \ScreenTime.totalScreenTime, order: .reverse) private var screenTimes: [ScreenTime]
    
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
                                    
                                    // Display the total screen time (formatted cleanly)
                                    // You can change "min" to "sec" or whatever unit you decide to track
                                    Text("\(screenTime.totalScreenTime, specifier: "%.0f") s")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
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
