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
                    LockedSectionLabel(title: "Screen Time setup", icon: "hourglass")

                    Text("Locked uses Apple’s Screen Time APIs to measure usage and lock apps. Do this once.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    StepCard(
                        stepNumber: 1,
                        title: "Allow Screen Time",
                        instructions: [
                            "On Home, tap **Allow Screen Time** and approve Locked.",
                            "This lets Locked read app usage and place a system lock screen on apps you haven’t earned back."
                        ]
                    )

                    StepCard(
                        stepNumber: 2,
                        title: "Choose apps",
                        instructions: [
                            "Tap **Choose Apps** and pick what Locked is allowed to manage.",
                            "You can select individual apps or whole categories. If you previously picked only categories, open Choose Apps again and tap Done so Locked can see each app token. Sunday still locks specific apps, and unlocking with Keys opens just that app.",
                            "**Locked, Settings, Phone, Messages, FaceTime, Find My, Wallet, and Clock never appear and never lock** — they also don’t count toward usage percentages."
                        ]
                    )

                    ScreenTimeGuideActions()
                }

                VStack(alignment: .leading, spacing: 12) {
                    LockedSectionLabel(title: "Rankings", icon: "chart.bar.fill")

                    LockedCard {
                        Text("App usage is always sorted from most time to least time. Deleted apps drop off the list and no longer count toward the totals.")
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
                            Text("If you truly cannot wait — a ride, a family call, a real emergency — break the glass on Home. Strike it three times. Every lock lifts for one hour, then snaps back on its own. While the seal is broken, an inner vault card appears at the bottom of Home in place of the glass. Spin the 3-number combination to add or remove Keys and Karma one step at a time. Keys stay at 0 or above; Karma stays between 0 and 100. This is a last resort.")
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

private struct ScreenTimeGuideActions: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager

    var body: some View {
        VStack(spacing: 10) {
            Button {
                if screenTime.isAuthorized {
                    screenTime.presentPicker()
                } else {
                    Task { await screenTime.requestAuthorization() }
                }
            } label: {
                Label(
                    screenTime.isAuthorized ? "Choose apps" : "Allow Screen Time",
                    systemImage: screenTime.isAuthorized ? "apps.iphone" : "checkmark.shield.fill"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.lockedIndigo)

            if screenTime.isAuthorized && screenTime.hasSelection {
                Text("Screen Time is connected. You can change the app list any time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
