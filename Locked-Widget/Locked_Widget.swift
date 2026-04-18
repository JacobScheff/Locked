import WidgetKit
import SwiftUI
import AppIntents // 1. Import AppIntents

// MARK: - App Intent
struct IncrementKeysIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Keys"
    
    // This function runs when the button is pressed
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")
        let currentKeys = sharedDefaults?.integer(forKey: "keys") ?? 0
        sharedDefaults?.set(currentKeys + 1, forKey: "keys")
        
        // This tells WidgetKit to update the UI immediately
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
        
        return .result()
    }
}

// MARK: - Provider
struct Provider: TimelineProvider {
    let sharedDefaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), keys: 5, karma: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let keys = sharedDefaults?.integer(forKey: "keys") ?? 5
        let karma = sharedDefaults?.integer(forKey: "karma") ?? 12
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
                    keysStatWithButton // Use the version with the button
                }
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    karmaStat
                    keysStatWithButton // Use the version with the button
                }
            }
        }
    }
    
    private var karmaStat: some View {
        StatItemView(icon: "sparkles", color: .purple, title: "Karma", value: entry.karma)
    }
    
    // This section adds the interactive button
    private var keysStatWithButton: some View {
        HStack {
            StatItemView(icon: "key.fill", color: .orange, title: "Keys", value: entry.keys)
            
            // 2. The Interactive Button
            Button(intent: IncrementKeysIntent()) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.orange.gradient)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain) // Essential for widgets to prevent default button styling
        }
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
