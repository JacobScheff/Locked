import WidgetKit
import SwiftUI

// MARK: - Palette (mirrored from Locked/Theme.swift; this target does not compile that file)

private enum WidgetPalette {
    static let teal = Color(red: 0.18, green: 0.78, blue: 0.72)
    static let amber = Color(red: 0.97, green: 0.70, blue: 0.22)
    static let hazardYellow = Color(red: 0.98, green: 0.78, blue: 0.12)

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

    static var overrideGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.07, blue: 0.10),
                Color(red: 0.18, green: 0.05, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var ringGradient: LinearGradient {
        LinearGradient(
            colors: [.white, teal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Provider

struct Provider: TimelineProvider {
    let sharedDefaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), keys: 14, karma: 82, appCount: 12, overrideUntil: .distantPast)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(currentEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let now = Date()
        let until = Date(timeIntervalSince1970: sharedDefaults?.double(forKey: "emergencyOverrideUntil") ?? 0)
        let sample = currentEntry(at: now)

        if until > now {
            completion(Timeline(entries: overrideEntries(from: now, until: until, template: sample), policy: .after(until)))
            return
        }

        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [sample], policy: .after(nextMidnight)))
    }

    private func currentEntry(at date: Date) -> SimpleEntry {
        let keys = sharedDefaults?.object(forKey: "keys") == nil
            ? 0
            : Int(sharedDefaults?.double(forKey: "keys") ?? 0)
        let karma = sharedDefaults?.object(forKey: "karma") == nil
            ? 100
            : Int(sharedDefaults?.double(forKey: "karma") ?? 100)
        let until = Date(timeIntervalSince1970: sharedDefaults?.double(forKey: "emergencyOverrideUntil") ?? 0)
        return SimpleEntry(
            date: date,
            keys: keys,
            karma: karma,
            appCount: loadAppCount(),
            overrideUntil: until
        )
    }

    private func loadAppCount() -> Int {
        guard let raw = sharedDefaults?.string(forKey: "appCounts"),
              let data = raw.data(using: .utf8),
              let counts = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return 0 }
        return counts.count
    }

    private func overrideEntries(from now: Date, until: Date, template: SimpleEntry) -> [SimpleEntry] {
        var entries: [SimpleEntry] = []
        var date = now
        let remaining = until.timeIntervalSince(now)
        let step: TimeInterval = remaining > 90 * 60 ? 5 * 60 : 60
        while date < until && entries.count < 70 {
            entries.append(
                SimpleEntry(
                    date: date,
                    keys: template.keys,
                    karma: template.karma,
                    appCount: template.appCount,
                    overrideUntil: until
                )
            )
            date = date.addingTimeInterval(step)
        }
        entries.append(
            SimpleEntry(
                date: until,
                keys: template.keys,
                karma: template.karma,
                appCount: template.appCount,
                overrideUntil: .distantPast
            )
        )
        return entries
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let keys: Int
    let karma: Int
    let appCount: Int
    let overrideUntil: Date

    var overrideActive: Bool { overrideUntil > date }

    var appsLockingThisWeek: Int {
        guard appCount > 0 else { return 0 }
        let lockPercent = max(0.0, min(100.0, 100.0 - Double(karma)))
        return min(appCount, Int((lockPercent / 100.0 * Double(appCount)).rounded(.up)))
    }

    var lockCountCopy: String {
        switch appsLockingThisWeek {
        case 0:
            return "No apps will lock this week"
        case 1:
            return "1 app will lock this week"
        default:
            return "\(appsLockingThisWeek) apps will lock this week"
        }
    }

    var remaining: TimeInterval {
        max(0, overrideUntil.timeIntervalSince(date))
    }
}

// MARK: - Widget View

struct Locked_WidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        Group {
            if entry.overrideActive {
                overrideView
            } else if widgetFamily == .systemMedium {
                mediumView
            } else {
                smallView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(widgetFamily == .systemSmall ? 12 : 16)
        .padding(.top, entry.overrideActive ? 6 : 0)
    }

    // MARK: Small — ring + keys, so the 2x2 stays uncluttered

    private var smallView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                KarmaRing(karma: entry.karma, size: 82, lineWidth: 8, numberSize: 28)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 8)
            KeysChip(keys: entry.keys)
        }
    }

    // MARK: Medium — ring, status copy, keys

    private var mediumView: some View {
        HStack(alignment: .center, spacing: 16) {
            KarmaRing(karma: entry.karma, size: 88, lineWidth: 9, numberSize: 30)
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.lockCountCopy)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                KeysChip(keys: entry.keys)
            }
        }
    }

    // MARK: Override — hazard treatment + remaining time

    @ViewBuilder
    private var overrideView: some View {
        if widgetFamily == .systemMedium {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    overrideIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SEAL BROKEN")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(WidgetPalette.hazardYellow)
                            .tracking(1.1)
                        Text("Locks are suspended")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(remainingText)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetPalette.hazardYellow)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("remaining")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                overrideIcon
                Text("SEAL BROKEN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetPalette.hazardYellow)
                    .tracking(1.1)
                Spacer(minLength: 4)
                Text(remainingText)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetPalette.hazardYellow)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("until locks return")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
    }

    private var overrideIcon: some View {
        Image(systemName: "lock.open.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(WidgetPalette.hazardYellow)
            .frame(width: 32, height: 32)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var remainingText: String {
        let total = max(0, Int(entry.remaining))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes == 0 { return "<1m" }
        return "\(minutes)m"
    }
}

// MARK: - Pieces

private struct KarmaRing: View {
    let karma: Int
    var size: CGFloat
    var lineWidth: CGFloat
    var numberSize: CGFloat

    private var progress: Double {
        min(max(Double(karma) / 100.0, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(WidgetPalette.ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(karma)")
                    .font(.system(size: numberSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("KARMA")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Karma \(karma) of 100")
    }
}

private struct KeysChip: View {
    let keys: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetPalette.amber)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(keys)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Keys")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(keys) keys")
    }
}

private struct WidgetBackgroundView: View {
    var overrideActive: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if overrideActive {
                WidgetPalette.overrideGradient
            } else {
                WidgetPalette.heroGradient
            }

            LinearGradient(
                colors: [Color.white.opacity(overrideActive ? 0.08 : 0.14), .clear],
                startPoint: .top,
                endPoint: .center
            )

            if overrideActive {
                WidgetHazardStripes()
                    .frame(height: 8)
            }
        }
    }
}

private struct WidgetHazardStripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let stripe: CGFloat = 10
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + stripe, y: 0))
                path.addLine(to: CGPoint(x: x + stripe + size.height, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(WidgetPalette.hazardYellow))
                x += stripe * 2
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Widget

struct Locked_Widget: Widget {
    let kind: String = "Locked_Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                Locked_WidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        WidgetBackgroundView(overrideActive: entry.overrideActive)
                    }
            } else {
                Locked_WidgetEntryView(entry: entry)
                    .background(WidgetBackgroundView(overrideActive: entry.overrideActive))
            }
        }
        .configurationDisplayName("Karma & Keys")
        .description("See your karma, keys, and whether the emergency seal is broken.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview("Small", as: .systemSmall) {
    Locked_Widget()
} timeline: {
    SimpleEntry(date: .now, keys: 14, karma: 82, appCount: 12, overrideUntil: .distantPast)
    SimpleEntry(date: .now, keys: 3, karma: 28, appCount: 12, overrideUntil: .distantPast)
}

#Preview("Medium", as: .systemMedium) {
    Locked_Widget()
} timeline: {
    SimpleEntry(date: .now, keys: 14, karma: 100, appCount: 12, overrideUntil: .distantPast)
    SimpleEntry(date: .now, keys: 14, karma: 82, appCount: 12, overrideUntil: .distantPast)
    SimpleEntry(date: .now, keys: 14, karma: 0, appCount: 1, overrideUntil: .distantPast)
}

#Preview("Override small", as: .systemSmall) {
    Locked_Widget()
} timeline: {
    SimpleEntry(date: .now, keys: 14, karma: 82, appCount: 12, overrideUntil: Date().addingTimeInterval(47 * 60))
}

#Preview("Override medium", as: .systemMedium) {
    Locked_Widget()
} timeline: {
    SimpleEntry(date: .now, keys: 14, karma: 82, appCount: 12, overrideUntil: Date().addingTimeInterval(47 * 60))
}
