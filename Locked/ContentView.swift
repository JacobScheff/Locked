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
    @Query private var screenTimes: [ScreenTime]

    var body: some View {
        Text("Hello World!")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ScreenTime.self, inMemory: true)
}
