import FamilyControls
import ManagedSettings
import SwiftUI

/// Names we know are drawn as ordinary centered text.
///
/// Screen Time's `Label` is the fallback for a token whose name we have never
/// been told. It draws out of process: it ignores font and alignment, reports
/// a placeholder size to `fixedSize`, and always starts its text at the
/// leading edge of whatever box it gets. It cannot be centered, so the box is
/// sized close to a typical app name to keep it near the middle.
struct CenteredAppName: View {
    enum Style {
        case grid
        case sheet
    }

    var token: ApplicationToken?
    var title: String?
    var style: Style

    private var knownTitle: String? {
        guard let title else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Locked app" ? nil : trimmed
    }

    private var font: Font {
        switch style {
        case .grid: return .system(size: 11, weight: .medium, design: .rounded)
        case .sheet: return .title3.weight(.bold)
        }
    }

    /// The remote label draws at body size whatever font it is given, so both
    /// places need the same box.
    private let fallbackBoxWidth: CGFloat = 64

    var body: some View {
        Group {
            if let knownTitle {
                Text(knownTitle)
                    .font(font)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
            } else if let token {
                Label(token)
                    .labelStyle(.titleOnly)
                    .frame(width: fallbackBoxWidth)
            } else {
                Text("Locked app")
                    .font(font)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
