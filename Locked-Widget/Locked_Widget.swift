import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    // Shared UserDefaults
    let sharedDefaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), keys: 0, karma: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let keys = sharedDefaults?.integer(forKey: "keys") ?? 0
        let karma = sharedDefaults?.integer(forKey: "karma") ?? 0
        let entry = SimpleEntry(date: Date(), keys: keys, karma: karma)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Fetch current values
        let keys = sharedDefaults?.integer(forKey: "keys") ?? 0
        let karma = sharedDefaults?.integer(forKey: "karma") ?? 0
        
        let entry = SimpleEntry(date: Date(), keys: keys, karma: karma)

        // Create timeline with the current data
        // We use .atEnd because the app will manually trigger refreshes when data changes
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let keys: Int
    let karma: Int
}

struct Locked_WidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Keys: \(entry.keys)")
                .font(.headline)
            Text("Karma: \(entry.karma)")
                .font(.headline)
        }
    }
}

struct Locked_Widget: Widget {
    let kind: String = "Locked_Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                Locked_WidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                Locked_WidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Locked Stats")
        .description("Track your keys and karma.")
    }
}

#Preview(as: .systemSmall) {
    Locked_Widget()
} timeline: {
    SimpleEntry(date: .now, keys: 5, karma: 10)
    SimpleEntry(date: .now, keys: 8, karma: 12)
}
