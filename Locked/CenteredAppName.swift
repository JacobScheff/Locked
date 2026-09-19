import FamilyControls
import ManagedSettings
import SwiftUI

/// Screen Time `Label` is a remote view: it ignores `.font` and
/// `.multilineTextAlignment`, and it fills whatever width it is offered.
/// `fixedSize` shrinks it to the name so a normal frame can center it, and
/// `scaleEffect` stands in for the font size it will not accept.
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

    /// The remote label draws at body size (17pt) no matter what.
    private var scale: CGFloat {
        switch style {
        case .grid: return 11 / 17
        case .sheet: return 20 / 17
        }
    }

    private var lineHeight: CGFloat {
        switch style {
        case .grid: return 14
        case .sheet: return 26
        }
    }

    var body: some View {
        Group {
            if let knownTitle {
                Text(knownTitle)
                    .font(font)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else if let token {
                Label(token)
                    .labelStyle(.titleOnly)
                    .fixedSize()
                    .scaleEffect(scale, anchor: .center)
                    .frame(height: lineHeight)
            } else {
                Text("Locked app")
                    .font(font)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .clipped()
    }
}
