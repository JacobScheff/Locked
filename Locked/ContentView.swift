import SwiftUI
import SwiftData
import WidgetKit // Required to trigger widget updates

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \ScreenTime.totalScreenTime, order: .reverse) private var screenTimes: [ScreenTime]
    
    // Shared App Group storage
    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Int = 0
    
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // MARK: - Top Stats (Karma & Keys)
                HStack(spacing: 40) {
                    // Karma Controls
                    VStack {
                        Text("Karma")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(karma)")
                            .font(.largeTitle)
                            .bold()
                        
                        HStack {
                            Button("-") {
                                karma -= 1
                                updateWidget()
                            }.buttonStyle(.bordered)
                            
                            Button("+") {
                                karma += 1
                                updateWidget()
                            }.buttonStyle(.bordered)
                        }
                    }
                    
                    // Keys Controls
                    VStack {
                        Text("Keys")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(keys)")
                            .font(.largeTitle)
                            .bold()
                        
                        HStack {
                            Button("-") {
                                keys -= 1
                                updateWidget()
                            }.buttonStyle(.bordered)
                            
                            Button("+") {
                                keys += 1
                                updateWidget()
                            }.buttonStyle(.bordered)
                        }
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
    
    // This tells the OS to refresh the widget immediately
    func updateWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ScreenTime.self, inMemory: true)
}
