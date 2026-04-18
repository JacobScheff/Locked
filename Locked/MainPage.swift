import SwiftUI
import WidgetKit

struct MainPage: View {
    @AppStorage("screentime", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var screentime: Int = 0 // Seconds
    
    var days: Int { screentime / 86400 }
    var hours: Int { (screentime % 86400) / 3600 }
    var minutes: Int { (screentime % 3600) / 60 }
    
    @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appCounts: [String: Int] = [:]
    
    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Int = 0
    
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Int = 0
    
    var body: some View {
        NavigationStack {
            List { // Using List for a cleaner look with dictionary items
                Section("Screen Time") {
                    Text("\(days) days, \(hours) hours, \(minutes) minutes")
                }

                Section("App Open Counts") {
                    // Sorting the keys so the list stays in order
                    ForEach(appCounts.keys.sorted(), id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            Text("\(appCounts[name] ?? 0)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            // Button to increment for testing
                            Button {
                                appCounts[name] = (appCounts[name] ?? 0) + 1
                                updateWidget()
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section("Stats") {
                    HStack {
                        VStack {
                            Text("Karma").font(.caption)
                            Text("\(karma)").font(.title2).bold()
                            HStack {
                                Button("-") { karma -= 1; updateWidget() }
                                Button("+") { karma += 1; updateWidget() }
                            }.buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()

                        VStack {
                            Text("Keys").font(.caption)
                            Text("\(keys)").font(.title2).bold()
                            HStack {
                                Button("-") { keys -= 1; updateWidget() }
                                Button("+") { keys += 1; updateWidget() }
                            }.buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Dashboard")
        }
    }
    
    func updateWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }
}
