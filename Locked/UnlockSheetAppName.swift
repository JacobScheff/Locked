import FamilyControls
import ManagedSettings
import SwiftUI

/// Placeholder title for the unlock sheet. The real name is logged until we
/// have a reliable way to draw token names in-process.
struct UnlockSheetAppName: View {
    var title: String
    var token: ApplicationToken?

    var body: some View {
        Text("Locked app")
            .font(.title3.weight(.bold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Locked app")
            .onAppear {
                print("Unlock sheet app name: \(resolvedName)")
            }
    }

    private var resolvedName: String {
        let candidates = [
            title,
            token.flatMap(UsageStore.displayName(for:))
        ]
        for name in candidates {
            guard let name else { continue }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != "Locked app" {
                return trimmed
            }
        }
        return "Locked app"
    }
}
