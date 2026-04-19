import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Provider
struct Provider: TimelineProvider {
    let sharedDefaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), keys: 5, karma: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let keys = sharedDefaults?.integer(forKey: "keys") ?? 0
        let karma = sharedDefaults?.integer(forKey: "karma") ?? 0
        let entry = SimpleEntry(date: Date(), keys: keys, karma: karma)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let keys = sharedDefaults?.integer(forKey: "keys") ?? 0
        let karma = sharedDefaults?.integer(forKey: "karma") ?? 0
        let entry = SimpleEntry(date: Date(), keys: keys, karma: karma)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let keys: Int
    let karma: Int
}

// MARK: - Widget View
struct Locked_WidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        Group {
            if widgetFamily == .systemMedium {
                HStack(spacing: 24) {
                    karmaStat
                    Divider().frame(height: 50).opacity(0.5)
                    keysStat
                }
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    karmaStat
                    keysStat
                }
            }
        }
    }
    
    private var karmaStat: some View {
        StatItemView(icon: "sparkles", color: .purple, title: "Karma", value: entry.karma)
    }
    
    private var keysStat: some View {
        StatItemView(icon: "key.fill", color: .orange, title: "Keys", value: entry.keys)
    }
}

struct StatItemView: View {
    let icon: String
    let color: Color
    let title: String
    let value: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.gradient.opacity(0.2))
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color.gradient)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Text("\(value)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
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
        .description("Track your keys and karma at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
