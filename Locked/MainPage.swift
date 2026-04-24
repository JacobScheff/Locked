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
        
    // Stores the custom user ranking order
    @AppStorage("appOrder", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appOrder: [String] = []
    
    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Int = 0
    
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Int = 0
    
    @AppStorage("lockedApps", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var lockedApps: [String] = []
    
    @State private var showingHowToUse = false
        
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
                    
                    AppCountsCard(
                        appCounts: $appCounts,
                        appOrder: $appOrder,
                        keys: $keys,
                        lockedApps: $lockedApps,
                        updateWidget: updateWidget
                    )
                    
                    // MARK: - TEMPORARY TEST BUTTON
                    // (Small, separate, and easy to delete later)
                    Button("Run Unscheduled App Locking") {
                        performSundayLocking()
                        updateWidget()
                    }
                    .font(.caption.bold())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
                    
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHowToUse = true
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showingHowToUse) {
                HowToUseView()
            }
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
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 12)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                VStack(spacing: -2) {
                    Text("\(karma)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
            }
            .frame(height: 110)
            .padding(.vertical, 10)
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
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - App Counts Card

struct AppCountsCard: View {
    @Binding var appCounts: [String: Int]
    @Binding var appOrder: [String]
    @Binding var keys: Int
    @Binding var lockedApps: [String]
    var updateWidget: () -> Void
    
    var totalAppCounts: Double { Double(appCounts.values.reduce(0, +)) }
    
    @State private var isEditing = false
    @State private var draftOrder: [String] = []
    @State private var draggedItem: String? = nil
    
    // Unlock Alert State
    @State private var showUnlockAlert = false
    @State private var appToUnlock: String?
    @State private var unlockCost: Int = 0
    
    var activeOrder: [String] {
        var current = appOrder.filter { appCounts.keys.contains($0) }
        let missing = appCounts.keys.filter { !current.contains($0) }
        let sortedMissing = missing.sorted { (appCounts[$0] ?? 0) > (appCounts[$1] ?? 0) }
        current.append(contentsOf: sortedMissing)
        return current
    }
    
    var displayOrder: [String] {
        isEditing ? draftOrder : activeOrder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.pink)
                Text(isEditing ? "Edit Rankings" : "App Usage")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !isEditing && !appCounts.isEmpty {
                    Button {
                        draftOrder = activeOrder
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isEditing = true
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(.indigo)
                            .padding(8)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(20)
            
            // MARK: - Edit Action Buttons
            if isEditing {
                HStack(spacing: 10) {
                    // Discard Button
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isEditing = false
                        }
                    } label: {
                        Text("Discard").font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.red.opacity(0.8))
                    
                    // Re-added Default Button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            draftOrder = draftOrder.sorted { a, b in
                                let countA = appCounts[a] ?? 0
                                let countB = appCounts[b] ?? 0
                                return countA == countB ? a < b : countA > countB
                            }
                        }
                    } label: {
                        Text("Default").font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    
                    // Save Button
                    Button {
                        appOrder = draftOrder
                        updateWidget()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isEditing = false
                        }
                    } label: {
                        Text("Save").font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.green)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // List Section
            if appCounts.isEmpty {
                Text("No apps recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(displayOrder.enumerated()), id: \.element) { index, name in
                        let isLocked = lockedApps.contains(name)
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text("#\(index + 1)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 36, alignment: .leading)
                                
                                AppIconView(appName: name)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text(name)
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 0)
                                
                                Spacer()
                                
                                if isEditing {
                                    reorderHandle(for: name)
                                } else {
                                    if isLocked {
                                        Button("Unlock") {
                                            appToUnlock = name
                                            unlockCost = calculateUnlockCost(for: name)
                                            showUnlockAlert = true
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.blue)
                                        .controlSize(.small)
                                    } else {
                                        let count = Double(appCounts[name] ?? 0)
                                        let percentage = totalAppCounts > 0 ? count / totalAppCounts : 0
                                        
                                        AppUsageBar(percentage: percentage)
                                            .frame(width: 130)
                                    }
                                }
                            }
                            .padding(.horizontal, 15)
                            .frame(height: 52)
                            // Gray out if locked
                            .grayscale(isLocked ? 1.0 : 0.0)
                            .opacity(isLocked ? 0.5 : (draggedItem == name ? 0.5 : 1.0))
                            
                            if name != displayOrder.last {
                                Divider().padding(.leading, 62)
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .zIndex(draggedItem == name ? 1 : 0)
                    }
                }
                .coordinateSpace(name: "ListArea")
                .padding(.bottom, 8)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        // MARK: - Unlock Alert
        .alert("Unlock App", isPresented: $showUnlockAlert, presenting: appToUnlock) { app in
            Button("Unlock (\(unlockCost) Keys)") {
                keys -= unlockCost
                lockedApps.removeAll { $0 == app }
                updateWidget()
            }
            Button("Cancel", role: .cancel) { }
        } message: { app in
            Text("Unlocking \(app) will cost \(unlockCost) keys. Do you want to proceed?")
        }
    }

    private func reorderHandle(for name: String) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("ListArea"))
                    .onChanged { value in
                        if draggedItem == nil { draggedItem = name }
                        let rowHeight: CGFloat = 53
                        let clampedIndex = max(0, min(draftOrder.count - 1, Int(value.location.y / rowHeight)))
                        if let currentIdx = draftOrder.firstIndex(of: name), currentIdx != clampedIndex {
                            withAnimation(.spring(response: 0.3)) {
                                draftOrder.move(fromOffsets: IndexSet(integer: currentIdx), toOffset: clampedIndex > currentIdx ? clampedIndex + 1 : clampedIndex)
                            }
                        }
                    }
                    .onEnded { _ in draggedItem = nil }
            )
    }
    
    // Calculates unlock cost in Keys based on logic file formula
    private func calculateUnlockCost(for app: String) -> Int {
        let totalUsage = Double(appCounts.values.reduce(0, +))
        let appUsage = Double(appCounts[app] ?? 0)
        let usagePercentage = totalUsage > 0 ? (appUsage / totalUsage) * 100.0 : 0.0
        
        let cost = pow(Double(lockedApps.count), 1.5) + 0.5 * pow(usagePercentage, 1.25) + 10.0
        return Int(cost.rounded()) // Returning as Int to match `keys` type
    }
}

struct AppUsageBar: View {
    let percentage: Double
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.pink.opacity(0.8), .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(percentage), 4))
                }
            }
            .frame(height: 8)
            
            Text("\(Int(percentage * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
