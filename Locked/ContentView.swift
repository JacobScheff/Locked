import SwiftUI
import WidgetKit

struct ContentView: View {
    @AppStorage("screentime", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var screentime: Int = 0 // Seconds
    
    var days: Int { screentime / 86400 }
    var hours: Int { (screentime % 86400) / 3600 }
    var minutes: Int { (screentime % 3600) / 60 }
    
    @AppStorage("startTimes", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var startTimes: [Date] = []
    
    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Int = 0
    
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // MARK: - Screen Time
                Text("Screen Time")
                Text("\(days) days, \(hours) hours, \(minutes) minutes")
                
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
}
