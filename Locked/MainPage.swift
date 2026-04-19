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
                        updateWidget: updateWidget
                    )
                                        
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

// MARK: - App Counts Card (With Custom Reordering Logic)

struct AppCountsCard: View {
    @Binding var appCounts: [String: Int]
    @Binding var appOrder: [String]
    var updateWidget: () -> Void
    
    @State private var isEditing = false
    @State private var draftOrder: [String] = []
    
    // Custom drag gesture state
    @State private var draggedItem: String? = nil
    
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
            // MARK: - Header
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.pink)
                Text(isEditing ? "Edit Rankings" : "App Usage Rankings")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
                
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
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(20)
            
            // MARK: - Edit Action Buttons
            if isEditing {
                HStack {
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
            
            // MARK: - List
            if appCounts.isEmpty {
                Text("No apps recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(displayOrder.enumerated()), id: \.element) { index, name in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                
                                
                                Text("#\(index + 1)")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 40, alignment: .leading)
                                
                                Text(name)
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .layoutPriority(1)
                                
                                Spacer()
                                
                                if isEditing {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 40, height: 40) // Generous touch target
                                        .contentShape(Rectangle())
                                        .gesture(
                                            DragGesture(minimumDistance: 3, coordinateSpace: .named("ListArea"))
                                                .onChanged { value in
                                                    if draggedItem == nil {
                                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                            draggedItem = name
                                                        }
                                                    }
                                                    
                                                    let rowHeight: CGFloat = 53
                                                    let rawIndex = Int(value.location.y / rowHeight)
                                                    let clampedIndex = max(0, min(draftOrder.count - 1, rawIndex))
                                                    
                                                    // Trigger the slide
                                                    if let currentIdx = draftOrder.firstIndex(of: name), currentIdx != clampedIndex {
                                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                            draftOrder.move(fromOffsets: IndexSet(integer: currentIdx),
                                                                            toOffset: clampedIndex > currentIdx ? clampedIndex + 1 : clampedIndex)
                                                        }
                                                    }
                                                }
                                                .onEnded { _ in
                                                    // Clear state on let go
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                        draggedItem = nil
                                                    }
                                                }
                                        )
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                } else {
                                    Text("\(appCounts[name] ?? 0)")
                                        .font(.system(.title3, design: .rounded, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 30, alignment: .trailing)
                                        .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 52)
                            
                            // Separators
                            if name != displayOrder.last {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                                    // 20 (horizontal padding) + 40 (rank width) + 12 (HStack spacing) = 72
                                    .padding(.leading, 72)
                            } else {
                                // Keeps the absolute row height perfectly uniform for the bottom element
                                Color.clear.frame(height: 1)
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .opacity(draggedItem == name ? 0.5 : 1.0)
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
    }
}
