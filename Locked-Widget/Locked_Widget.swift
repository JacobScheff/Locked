import WidgetKit
import SwiftUI

// MARK: - Provider
struct Provider: TimelineProvider {
    let sharedDefaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), keys: 14, karma: 82)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let timeline = Timeline(entries: [currentEntry()], policy: .atEnd)
        completion(timeline)
    }

    private func currentEntry() -> SimpleEntry {
        let keys = Int(sharedDefaults?.double(forKey: "keys") ?? 0)
        let karma = Int(sharedDefaults?.double(forKey: "karma") ?? 0)
        return SimpleEntry(date: Date(), keys: keys, karma: karma)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let keys: Int
    let karma: Int
}

// MARK: - Widget View
struct Locked_WidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        Group {
            if widgetFamily == .systemMedium {
                HStack(spacing: 0) {
                    karmaBlock
                    Spacer(minLength: 12)
                    Divider().opacity(0.25)
                    Spacer(minLength: 12)
                    keysBlock
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    karmaBlock
                    keysBlock
                }
            }
        }
    }

    private var karmaBlock: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.18), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: min(max(Double(entry.karma) / 100.0, 0), 1))
                    .stroke(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(entry.karma)")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("KARMA")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(karmaCaption)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var keysBlock: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.18))
                Image(systemName: "key.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.orange.gradient)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("KEYS")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                Text("\(entry.keys)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
    }

    private var karmaCaption: String {
        switch entry.karma {
        case 90...: return "Well protected"
        case 70..<90: return "Mostly safe"
        case 40..<70: return "Apps at risk"
        default: return "Lockdown likely"
        }
    }
}

struct Locked_Widget: Widget {
    let kind: String = "Locked_Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                Locked_WidgetEntryView(entry: entry)
                    .containerBackground(.background, for: .widget)
            } else {
                Locked_WidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(UIColor.systemBackground))
            }
        }
        .configurationDisplayName("Locked Stats")
        .description("Karma, keys, and whether your apps are safe this week.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
