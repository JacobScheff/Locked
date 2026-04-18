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
            ScrollView {
                VStack(spacing: 24) {
                    
                    HeaderView()
                    
                    ScreenTimeCard(days: days, hours: hours, minutes: minutes)
                    
                    HStack(spacing: 16) {
                        KarmaCard(karma: $karma, updateWidget: updateWidget)
                        KeysCard(keys: $keys, updateWidget: updateWidget)
                    }
                    
                    AppCountsCard(appCounts: $appCounts, updateWidget: updateWidget)
                    
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        }
    }
    
    func updateWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }
}

// MARK: - Subviews

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .indigo.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("Locked")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .tracking(1.5)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

struct ScreenTimeCard: View {
    let days: Int
    let hours: Int
    let minutes: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "hourglass")
                    .foregroundStyle(.cyan)
                    .fontWeight(.bold)
                Text("Screen Time")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 12) {
                TimeBlock(value: days, unit: "Days")
                TimeBlock(value: hours, unit: "Hours")
                TimeBlock(value: minutes, unit: "Min")
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct TimeBlock: View {
    let value: Int
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(unit)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct KarmaCard: View {
    @Binding var karma: Int
    var updateWidget: () -> Void
    
    var progress: Double {
        min(max(Double(karma) / 100.0, 0.0), 1.0)
    }
    
    var body: some View {
        VStack {
            Text("Karma")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 12)
                
                // Progress Bar
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                // Inner Text
                VStack(spacing: -2) {
                    Text("\(karma)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("Karma")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            .frame(height: 110)
            .padding(.vertical, 10)
            
            Spacer()
            
            HStack(spacing: 12) {
                ControlButton(icon: "minus", action: { karma -= 1; updateWidget() })
                ControlButton(icon: "plus", action: { karma += 1; updateWidget() })
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct KeysCard: View {
    @Binding var keys: Int
    var updateWidget: () -> Void
    
    var body: some View {
        VStack {
            Text("Keys")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 5, x: 0, y: 3)
                
                Text("\(keys)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            .padding(.vertical, 10)
            
            Spacer()
            
            HStack(spacing: 12) {
                ControlButton(icon: "minus", action: { keys -= 1; updateWidget() })
                ControlButton(icon: "plus", action: { keys += 1; updateWidget() })
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// TODO: Delete Me!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
struct ControlButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .foregroundStyle(.primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain) // Prevents highlighting the whole card
    }
}

struct AppCountsCard: View {
    @Binding var appCounts: [String: Int]
    var updateWidget: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.pink)
                Text("App Open Counts")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            
            if appCounts.isEmpty {
                Text("No apps recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appCounts.keys.sorted()), id: \.self) { name in
                        HStack {
                            Text(name)
                                .font(.system(.body, design: .rounded, weight: .medium))
                            Spacer()
                            Text("\(appCounts[name] ?? 0)")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 30, alignment: .trailing)
                            
                            Button {
                                appCounts[name] = (appCounts[name] ?? 0) + 1
                                updateWidget()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        
                        if name != appCounts.keys.sorted().last {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
