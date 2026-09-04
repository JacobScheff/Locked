import SwiftUI

// MARK: - Palette

extension Color {
    static let lockedIndigo = Color(red: 0.37, green: 0.38, blue: 0.96)
    static let lockedViolet = Color(red: 0.62, green: 0.38, blue: 0.95)
    static let lockedTeal = Color(red: 0.18, green: 0.78, blue: 0.72)
    static let lockedAmber = Color(red: 0.97, green: 0.70, blue: 0.22)
    static let lockedRose = Color(red: 0.93, green: 0.33, blue: 0.46)
    static let hazardYellow = Color(red: 0.98, green: 0.78, blue: 0.12)
    static let hazardRed = Color(red: 0.76, green: 0.12, blue: 0.18)
    static let vaultBrass = Color(red: 0.86, green: 0.70, blue: 0.38)
    static let vaultSteel = Color(red: 0.18, green: 0.22, blue: 0.26)
}

extension ShapeStyle where Self == Color {
    static var lockedIndigo: Color { Color.lockedIndigo }
    static var lockedViolet: Color { Color.lockedViolet }
    static var lockedTeal: Color { Color.lockedTeal }
    static var lockedAmber: Color { Color.lockedAmber }
    static var lockedRose: Color { Color.lockedRose }
    static var hazardYellow: Color { Color.hazardYellow }
    static var hazardRed: Color { Color.hazardRed }
    static var vaultBrass: Color { Color.vaultBrass }
    static var vaultSteel: Color { Color.vaultSteel }
}

enum LockedTheme {
    static let cardRadius: CGFloat = 22

    static var karmaGradient: LinearGradient {
        LinearGradient(
            colors: [.lockedViolet, .lockedIndigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.18, blue: 0.58),
                Color(red: 0.33, green: 0.22, blue: 0.72),
                Color(red: 0.16, green: 0.42, blue: 0.68)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var keysGradient: LinearGradient {
        LinearGradient(
            colors: [.lockedAmber, Color.orange],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Typography

extension Font {
    static func lockedTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func lockedNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

// MARK: - Card chrome

struct LockedCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LockedCardBackground())
    }
}

struct LockedCardBackground: View {
    var cornerRadius: CGFloat = LockedTheme.cardRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

struct LockedSectionLabel<Accessory: View>: View {
    let title: String
    var icon: String? = nil
    var accessory: Accessory

    init(title: String, icon: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.icon = icon
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            accessory
        }
    }
}

extension LockedSectionLabel where Accessory == EmptyView {
    init(title: String, icon: String? = nil) {
        self.init(title: title, icon: icon) { EmptyView() }
    }
}

struct LockedBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    Color.lockedIndigo.opacity(0.14),
                    Color.clear,
                    Color.lockedTeal.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct LockedLaunchOverlay: View {
    @State private var spin = false
    @State private var glow = false

    var body: some View {
        ZStack {
            LockedBackground()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.lockedIndigo.opacity(glow ? 0.16 : 0.08))
                        .frame(width: 108, height: 108)

                    Circle()
                        .stroke(Color.lockedIndigo.opacity(0.16), lineWidth: 4)
                        .frame(width: 78, height: 78)

                    Circle()
                        .trim(from: 0.08, to: 0.72)
                        .stroke(
                            LockedTheme.karmaGradient,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 78, height: 78)
                        .rotationEffect(.degrees(spin ? 360 : 0))

                    Image(systemName: "lock.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.lockedIndigo)
                }

                VStack(spacing: 6) {
                    Text("Locked")
                        .font(.lockedTitle(28))
                    Text("Getting things ready")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 0.95).repeatForever(autoreverses: false)) {
                spin = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// MARK: - Rings

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var gradient: LinearGradient = LockedTheme.karmaGradient
    var trackOpacity: Double = 0.16

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.82), value: progress)
        }
    }
}

// MARK: - Helpers

enum WeeklyLock {
    static var daysUntilSunday: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 0 : 8 - weekday
    }

    static var subtitle: String {
        switch daysUntilSunday {
        case 0: return "Weekly lock is today"
        case 1: return "Weekly lock is tomorrow"
        default: return "Weekly lock in \(daysUntilSunday) days"
        }
    }
}

enum Greeting {
    static var current: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

func formatScreenTime(days: Int, hours: Int, minutes: Int) -> String {
    var parts: [String] = []
    if days > 0 { parts.append("\(days)d") }
    if hours > 0 { parts.append("\(hours)h") }
    parts.append("\(minutes)m")
    return parts.joined(separator: " ")
}

func formatAppDuration(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
    if hours > 0 { return "\(hours)h" }
    if minutes > 0 { return "\(minutes)m" }
    if seconds > 0 { return "<1m" }
    return "0m"
}

func karmaStatusCopy(karma: Double, appCount: Int) -> (headline: String, detail: String) {
    let lockPercent = max(0.0, min(100.0, 100.0 - karma))
    let numToLock = appCount == 0
        ? 0
        : Int((lockPercent / 100.0 * Double(appCount)).rounded(.up))

    let headline: String
    switch karma {
    case 90...: headline = "Your apps are well protected"
    case 70..<90: headline = "Most of your apps stay open"
    case 40..<70: headline = "Several apps are at risk"
    default: headline = "Most apps will lock this week"
    }

    let detail: String
    if appCount == 0 {
        return (headline, "Connect Screen Time to see which apps would lock.")
    }
    if numToLock == 0 {
        return ("You're fully protected", "No apps are scheduled to lock this Sunday.")
    }
    return (headline, "About \(numToLock) of \(appCount) apps lock on Sunday.")
}

func courseAccent(_ name: String) -> Color {
    let palette: [Color] = [
        .lockedIndigo, .lockedTeal, .lockedViolet, .orange,
        .pink, .blue, .mint, .cyan, .purple, .lockedRose
    ]
    let hash = name.unicodeScalars.reduce(into: 0) { $0 = $0 &+ Int($1.value) }
    return palette[abs(hash) % palette.count]
}
