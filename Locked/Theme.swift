import SwiftUI
import UIKit

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

    static var karmaGradient: AnyGradient { Color.lockedIndigo.gradient }
    static var heroGradient: AnyGradient { Color(red: 0.22, green: 0.18, blue: 0.58).gradient }
    static var keysGradient: AnyGradient { Color.lockedAmber.gradient }
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

struct LockedStatusPill: View {
    let text: String
    var color: Color = .lockedIndigo
    var filled = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(filled ? Color.white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(filled ? color : color.opacity(0.14))
            .clipShape(Capsule())
    }
}

struct LockedBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            Rectangle()
                .fill(Color.lockedIndigo.opacity(0.14).gradient)
        }
        .ignoresSafeArea()
    }
}

struct LockedLaunchOverlay: View {
    var body: some View {
        ZStack {
            LockedBackground()

            VStack(spacing: 26) {
                LockedLaunchSpinner()
                    .frame(width: 118, height: 118)

                VStack(spacing: 7) {
                    Text("Locked")
                        .font(.lockedTitle(30))
                    Text("Getting things ready")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Locked")
        .accessibilityValue("Getting things ready")
    }
}

/// The launch ring, without the full-screen cover, so a pushed page can
/// stay visible while usage finishes loading.
struct LockedLaunchSpinner: View {
    var body: some View {
        ZStack {
            LaunchEmblem()
            Image(systemName: "lock.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.lockedIndigo)
                .shadow(color: Color.lockedIndigo.opacity(0.25), radius: 8, y: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Core Animation drives the launch mark so the ring keeps moving even if
/// the main thread is busy building the first real screen.
private struct LaunchEmblem: UIViewRepresentable {
    func makeUIView(context: Context) -> LaunchEmblemView {
        LaunchEmblemView()
    }

    func updateUIView(_ uiView: LaunchEmblemView, context: Context) {}
}

private final class LaunchEmblemView: UIView {
    private let glowLayer = CALayer()
    private let discLayer = CALayer()
    private let trackLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    private var didStartAnimations = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        glowLayer.backgroundColor = UIColor(red: 0.37, green: 0.38, blue: 0.96, alpha: 1).cgColor
        glowLayer.opacity = 0.10
        layer.addSublayer(glowLayer)

        discLayer.backgroundColor = UIColor(red: 0.37, green: 0.38, blue: 0.96, alpha: 0.10).cgColor
        layer.addSublayer(discLayer)

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor(red: 0.37, green: 0.38, blue: 0.96, alpha: 0.18).cgColor
        trackLayer.lineWidth = 4
        layer.addSublayer(trackLayer)

        arcLayer.fillColor = UIColor.clear.cgColor
        arcLayer.strokeColor = UIColor.white.cgColor
        arcLayer.lineWidth = 4
        arcLayer.lineCap = .round
        arcLayer.strokeStart = 0.06
        arcLayer.strokeEnd = 0.78

        gradientLayer.colors = [
            UIColor(red: 0.62, green: 0.38, blue: 0.95, alpha: 1).cgColor,
            UIColor(red: 0.37, green: 0.38, blue: 0.96, alpha: 1).cgColor,
            UIColor(red: 0.18, green: 0.78, blue: 0.72, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.mask = arcLayer
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        glowLayer.frame = bounds.insetBy(dx: bounds.width * 0.02, dy: bounds.width * 0.02)
        glowLayer.cornerRadius = glowLayer.bounds.width / 2

        discLayer.frame = bounds.insetBy(dx: bounds.width * 0.08, dy: bounds.width * 0.08)
        discLayer.cornerRadius = discLayer.bounds.width / 2

        let ringInset = bounds.width * 0.17
        let ringRect = bounds.insetBy(dx: ringInset, dy: ringInset)
        let ringPath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: ringRect.size)).cgPath
        trackLayer.frame = ringRect
        trackLayer.path = ringPath

        gradientLayer.frame = ringRect
        arcLayer.frame = gradientLayer.bounds
        arcLayer.path = ringPath
        startAnimationsIfNeeded()
    }

    private func startAnimationsIfNeeded() {
        guard !didStartAnimations else { return }
        didStartAnimations = true

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = CGFloat.pi * 2
        spin.duration = 0.9
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        gradientLayer.add(spin, forKey: "spin")

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.07
        pulse.toValue = 0.18
        pulse.duration = 1.15
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.isRemovedOnCompletion = false
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(pulse, forKey: "pulse")
    }
}

// MARK: - Rings

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var gradient: AnyGradient = LockedTheme.karmaGradient
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

enum CourseAccent {
    private struct Swatch {
        let color: Color
        /// Red stays pickable, but is never assigned as a default accent.
        let isRed: Bool
    }

    private static let swatches: [Swatch] = [
        Swatch(color: .lockedIndigo, isRed: false),
        Swatch(color: .lockedTeal, isRed: false),
        Swatch(color: .lockedViolet, isRed: false),
        Swatch(color: .lockedAmber, isRed: false),
        Swatch(color: .lockedRose, isRed: true),
        Swatch(color: Color(red: 0.20, green: 0.62, blue: 0.96), isRed: false), // sky
        Swatch(color: Color(red: 0.98, green: 0.50, blue: 0.18), isRed: false), // orange
        Swatch(color: Color(red: 0.20, green: 0.70, blue: 0.42), isRed: false), // green
        Swatch(color: Color(red: 0.90, green: 0.32, blue: 0.62), isRed: false), // magenta
        Swatch(color: Color(red: 0.12, green: 0.52, blue: 0.58), isRed: false), // deep teal
        Swatch(color: Color(red: 0.52, green: 0.42, blue: 0.96), isRed: false), // periwinkle
        Swatch(color: Color(red: 0.82, green: 0.24, blue: 0.28), isRed: true), // crimson
        Swatch(color: Color(red: 0.45, green: 0.68, blue: 0.22), isRed: false), // lime
        Swatch(color: Color(red: 0.16, green: 0.38, blue: 0.74), isRed: false), // cobalt
        Swatch(color: Color(red: 0.78, green: 0.58, blue: 0.18), isRed: false), // gold
        Swatch(color: Color(red: 0.58, green: 0.30, blue: 0.68), isRed: false)  // plum
    ]

    static var palette: [Color] { swatches.map(\.color) }

    static var automaticIndices: [Int] {
        swatches.indices.filter { !swatches[$0].isRed }
    }

    static func isRed(_ index: Int) -> Bool {
        swatches.indices.contains(index) && swatches[index].isRed
    }

    static func color(for name: String, index: Int? = nil) -> Color {
        palette[resolvedIndex(name: name, index: index)]
    }

    static func resolvedIndex(name: String, index: Int?) -> Int {
        if let index, palette.indices.contains(index) {
            return index
        }
        return hashIndex(for: name)
    }

    static func resolvedIndex(for course: Course) -> Int {
        resolvedIndex(name: course.name, index: course.accentIndex)
    }

    static func leastUsedIndex(in courses: [Course]) -> Int {
        let candidates = automaticIndices
        var counts = Array(repeating: 0, count: palette.count)
        for course in courses {
            counts[resolvedIndex(for: course)] += 1
        }
        let fewest = candidates.map { counts[$0] }.min() ?? 0
        let tied = candidates.filter { counts[$0] == fewest }
        return tied.randomElement() ?? candidates.first ?? 0
    }

    static func hashIndex(for name: String) -> Int {
        let source = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = source.isEmpty ? "Course" : source
        var hash: UInt64 = 5381
        for (offset, scalar) in seed.unicodeScalars.enumerated() {
            hash = hash &* 33 &+ UInt64(scalar.value) &* UInt64(offset + 1)
        }
        hash ^= hash >> 13
        let candidates = automaticIndices
        guard !candidates.isEmpty else { return 0 }
        return candidates[Int(hash % UInt64(candidates.count))]
    }
}

struct CourseColorPicker: View {
    @Binding var selectedIndex: Int

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8),
            spacing: 10
        ) {
            ForEach(CourseAccent.palette.indices, id: \.self) { index in
                Button {
                    selectedIndex = index
                } label: {
                    Circle()
                        .fill(CourseAccent.palette[index])
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    Color.primary.opacity(selectedIndex == index ? 0.9 : 0),
                                    lineWidth: 2
                                )
                        }
                        .overlay {
                            if selectedIndex == index {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Course color \(index + 1)")
                .accessibilityAddTraits(selectedIndex == index ? .isSelected : [])
            }
        }
    }
}

func courseAccent(_ name: String, index: Int? = nil) -> Color {
    CourseAccent.color(for: name, index: index)
}

struct SpinningSyncIcon: View {
    var spinning: Bool
    var color: Color = .white
    var font: Font = .title3.weight(.bold)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !spinning)) { context in
            let turns = spinning
                ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.85) / 0.85
                : 0
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(font)
                .foregroundStyle(color)
                .rotationEffect(.degrees(turns * 360))
        }
        .accessibilityLabel(spinning ? "Refreshing" : "Refresh")
    }
}

extension View {
    /// SwiftUI cancels `.refreshable` when the view updates (for example when
    /// the toolbar spinner starts). Button taps use an unstructured `Task`, so
    /// they keep running. Pull-to-refresh should do the same.
    func lockedRefreshable(_ action: @escaping @MainActor () async -> Void) -> some View {
        refreshable {
            await withCheckedContinuation { continuation in
                Task { @MainActor in
                    await action()
                    continuation.resume()
                }
            }
        }
    }
}
