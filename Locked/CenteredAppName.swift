import FamilyControls
import ManagedSettings
import SwiftUI

/// Screen Time `Label` is a remote view. It ignores font and alignment, and
/// `fixedSize` collapses it to a sliver that clips the name. Give it a real
/// width so the full name can draw, then center that box.
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

    private var nameBoxWidth: CGFloat {
        switch style {
        case .grid: return 80
        case .sheet: return 120
        }
    }

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
                    .font(font)
                    .frame(width: nameBoxWidth)
            } else {
                Text("Locked app")
                    .font(font)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
