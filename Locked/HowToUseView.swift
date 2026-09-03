import SwiftUI
#if DEBUG
import WidgetKit
#endif

struct HowToUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                intro

                VStack(alignment: .leading, spacing: 12) {
                    LockedSectionLabel(title: "The loop", icon: "arrow.triangle.2.circlepath")

                    VStack(spacing: 10) {
                        LoopCard(
                            icon: "checkmark.circle.fill",
                            color: .lockedTeal,
                            title: "Finish work early",
                            detail: "Assignments you complete before the due date earn Karma. Every completion also grants Keys."
                        )
                        LoopCard(
                            icon: "star.fill",
                            color: .lockedViolet,
                            title: "Karma protects apps",
                            detail: "Higher Karma means fewer apps lock on Sunday — and the ones you use most are last to go."
                        )
                        LoopCard(
                            icon: "key.fill",
                            color: .lockedAmber,
                            title: "Keys buy your time back",
                            detail: "If something important gets locked, spend Keys to unlock it. Earn more by staying on top of coursework."
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    LockedSectionLabel(title: "Shortcuts setup", icon: "bolt.fill")

                    Text("Locked tracks which apps you open through the Shortcuts app. Do this once.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    StepCard(
                        stepNumber: 1,
                        title: "When an app opens",
                        instructions: [
                            "Open **Shortcuts** → **Automation**.",
                            "Create a new automation and choose **App**.",
                            "Select **Is Opened** and **Run Immediately**. Turn off *Notify When Run*.",
                            "Pick the apps you want Locked to manage.",
                            "Add **Get Current App**, then Locked’s **On App Open** action.",
                            "Set *App Name* to the *Current App* variable.",
                            "Add an **If** block: **If** *On App Open Result* is **True**.",
                            "Inside the If, add **Go to Home Screen** so locked apps bounce you out."
                        ]
                    )

                    StepCard(
                        stepNumber: 2,
                        title: "When an app closes",
                        instructions: [
                            "Create another **App** automation.",
                            "Choose **Is Closed** and **Run Immediately**. Turn off *Notify When Run*.",
                            "Select the same apps as before.",
                            "Add Locked’s **On App Close** action. No extra parameters needed."
                        ]
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    LockedSectionLabel(title: "Rankings", icon: "slider.horizontal.3")

                    LockedCard {
                        Text("App usage is ranked automatically. If you want a different lock order, tap Reorder on the Home screen and drag apps into place.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    LockedSectionLabel(title: "Emergency", icon: "light.beacon.max.fill")

                    LockedCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Break glass")
                                .font(.headline)
                            Text("If you truly cannot wait — a ride, a family call, a real emergency — break the glass on Home. Strike it three times. Every lock lifts for one hour, then snaps back on its own. It does not spend Keys or change Karma. This is a last resort, not a shortcut.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                #if DEBUG
                debugTools
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.large)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study first. Unlock later.")
                .font(.lockedTitle(28))
            Text("Locked closes distracting apps when coursework slips, and opens them back up when you follow through.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    #if DEBUG
    private var debugTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Developer", icon: "hammer.fill")
            Button {
                performSundayLocking()
                WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
            } label: {
                Label("Simulate weekly lock", systemImage: "lock.rotation")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.lockedRose)
        }
    }
    #endif
}

private struct LoopCard: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.15))
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(LockedCardBackground(cornerRadius: 18))
    }
}

struct StepCard: View {
    let stepNumber: Int
    let title: String
    let instructions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("\(stepNumber)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(LockedTheme.karmaGradient)
                    .clipShape(Circle())

                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { _, instruction in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.lockedIndigo.opacity(0.45))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text((try? AttributedString(markdown: instruction)) ?? AttributedString(instruction))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .background(LockedCardBackground())
    }
}
