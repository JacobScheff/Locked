import SwiftUI
import UIKit
import Combine

// MARK: - Home: inner vault entry (only while the glass is broken)

struct VaultSealCard: View {
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.vaultBrass.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.vaultBrass.opacity(0.4), lineWidth: 1)
                        )
                    Image(systemName: unlocked ? "lock.open.fill" : "gearshape.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.vaultBrass)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(unlocked ? "Vault open" : "Inner vault")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color.vaultBrass)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(unlocked
                         ? "Add or remove Keys and Karma one step at a time."
                         : "Hold the vault open to adjust Keys and Karma. Extreme use only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.vaultBrass.opacity(0.65))
            }
            .padding(16)
            .background(LockedCardBackground())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlocked
            ? "Inner vault is open. Adjust keys and karma."
            : "Inner vault. Hold to unlock, then adjust keys and karma.")
    }
}

// MARK: - Clockwork vault ritual

struct InnerVaultView: View {
    var onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss

    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Double = 0.0

    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0

    @AppStorage("emergencyOverrideUntil", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var emergencyOverrideUntil: Double = 0

    @State private var holding = false
    @State private var holdStartedAt: Date?
    @State private var charge = 0.0
    @State private var retractedBolts = 0
    @State private var irisOpen = false
    @State private var finishing = false
    @State private var revealed = false
    @State private var idleSpin = 0.0
    @State private var glow = 0.28
    @State private var hubPulse = false
    @State private var bloom = 0.0

    private var displayedKeys: Int { Int(clampKeys(keys).rounded(.towardZero)) }
    private var displayedKarma: Int { Int(clampKarma(karma).rounded(.towardZero)) }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if revealed {
                    treasury
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                } else {
                    lockedStage
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .interactiveDismissDisabled(!revealed)
        .onAppear(perform: prepare)
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { date in
            if !EmergencyOverride.isActive(at: date) {
                dismiss()
                return
            }
            tickHold(at: date)
        }
        .onChange(of: emergencyOverrideUntil) { _, _ in
            if !EmergencyOverride.isActive() { dismiss() }
        }
    }

    // MARK: Stages

    private var lockedStage: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Inner vault")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.vaultBrass)
                    .tracking(2.4)
                    .textCase(.uppercase)

                Text(holding ? "Retracting bolts" : "Hold the hub to open the vault.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            vaultDoor
                .frame(width: 292, height: 292)

            Text("A different lock sits behind the broken glass. Keys stay at 0 or above. Karma stays between 0 and 100.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
        }
    }

    private var treasury: some View {
        VStack(spacing: 26) {
            VStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.vaultBrass)
                Text("Reserves open")
                    .font(.lockedTitle(32))
                    .foregroundStyle(.white)
                Text("Change one step at a time.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 16) {
                ReserveStepper(
                    title: "Keys",
                    icon: "key.fill",
                    accent: Color.lockedAmber,
                    value: displayedKeys,
                    canIncrement: true,
                    canDecrement: displayedKeys > 0,
                    onIncrement: { stepKeys(1) },
                    onDecrement: { stepKeys(-1) }
                )
                ReserveStepper(
                    title: "Karma",
                    icon: "sparkle",
                    accent: Color.lockedViolet,
                    value: displayedKarma,
                    canIncrement: displayedKarma < 100,
                    canDecrement: displayedKarma > 0,
                    onIncrement: { stepKarma(1) },
                    onDecrement: { stepKarma(-1) }
                )
            }

            Text("Keys cannot go below 0. Karma cannot go below 0 or above 100.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Door

    private var vaultDoor: some View {
        let wheel = idleSpin * 0.12 + charge * 210
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.16, green: 0.20, blue: 0.24),
                            Color(red: 0.06, green: 0.07, blue: 0.09)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 160
                    )
                )
                .shadow(color: Color.lockedTeal.opacity(glow * (irisOpen ? 0.7 : 0.28)), radius: 28, y: 8)

            gearRing(teeth: 24, radius: 138, tooth: CGSize(width: 11, height: 17), angle: wheel)
            gearRing(teeth: 16, radius: 108, tooth: CGSize(width: 8, height: 12), angle: -wheel * 0.7)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.vaultBrass, Color.vaultBrass.opacity(0.35), Color.vaultBrass],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 7
                )
                .padding(18)

            Circle()
                .trim(from: 0, to: charge)
                .stroke(
                    Color.lockedTeal,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .padding(30)
                .rotationEffect(.degrees(-90))

            ForEach(0..<InnerVault.boltCount, id: \.self) { index in
                bolt(retracted: index < retractedBolts)
                    .rotationEffect(.degrees(Double(index) * 90 + wheel * 0.04))
            }

            Circle()
                .fill(Color.lockedTeal.opacity(bloom * 0.55))
                .blur(radius: 18)
                .padding(70)
                .opacity(irisOpen ? 1 : 0)

            iris
                .padding(48)

            hub
        }
        .gesture(holdGesture)
        .accessibilityLabel("Vault hub. Hold to retract the bolts.")
        .accessibilityAddTraits(.isButton)
    }

    private func gearRing(teeth: Int, radius: CGFloat, tooth: CGSize, angle: Double) -> some View {
        ZStack {
            ForEach(0..<teeth, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.vaultBrass.opacity(0.78))
                    .frame(width: tooth.width, height: tooth.height)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(Double(index) / Double(teeth) * 360 + angle))
            }
        }
        .allowsHitTesting(false)
    }

    private func bolt(retracted: Bool) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.84, blue: 0.52),
                        Color.vaultBrass,
                        Color(red: 0.52, green: 0.38, blue: 0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 16, height: 38)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .offset(y: retracted ? -72 : -118)
            .opacity(retracted ? 0.2 : 1)
            .animation(.interpolatingSpring(stiffness: 260, damping: 16), value: retracted)
    }

    private var iris: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                IrisPetal(count: 8, index: index)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.32, blue: 0.36),
                                Color(red: 0.10, green: 0.12, blue: 0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        IrisPetal(count: 8, index: index)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(irisOpen ? Double(index) * 14 : 0))
                    .scaleEffect(irisOpen ? 1.35 : 1)
                    .opacity(irisOpen ? 0 : 1)
            }
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.78), value: irisOpen)
        .allowsHitTesting(false)
    }

    private var hub: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.34, green: 0.28, blue: 0.16),
                            Color(red: 0.12, green: 0.10, blue: 0.07)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 46
                    )
                )
            Circle()
                .stroke(Color.vaultBrass.opacity(holding ? 0.95 : 0.55), lineWidth: 2)
            Image(systemName: irisOpen ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.vaultBrass)
                .scaleEffect(hubPulse && !holding ? 1.06 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: irisOpen)
        }
        .frame(width: 88, height: 88)
        .scaleEffect(holding ? 0.94 : 1)
        .animation(.easeOut(duration: 0.16), value: holding)
    }

    // MARK: Chrome

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color.lockedTeal.opacity(revealed ? 0.28 : 0.14),
                    Color.black
                ],
                center: .center,
                startRadius: 8,
                endRadius: 460
            )
            .animation(.easeIn(duration: 0.45), value: revealed)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button(revealed ? "Done" : "Cancel") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .frame(height: 44)
    }

    // MARK: Interaction

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in beginHold() }
            .onEnded { _ in cancelHold() }
    }

    private func prepare() {
        keys = clampKeys(keys)
        karma = clampKarma(karma)
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glow = 0.55
            hubPulse = true
        }
        withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) {
            idleSpin = 360
        }
        if InnerVault.isUnlocked() {
            charge = 1
            retractedBolts = InnerVault.boltCount
            finishing = true
            irisOpen = true
            bloom = 1
            revealed = true
        }
    }

    private func beginHold() {
        guard !revealed, !finishing, !holding else { return }
        holding = true
        holdStartedAt = Date()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
    }

    private func cancelHold() {
        guard holding, !revealed, !finishing else { return }
        holding = false
        holdStartedAt = nil
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
            charge = 0
            retractedBolts = 0
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func tickHold(at date: Date) {
        guard holding, let start = holdStartedAt, !revealed, !finishing else { return }
        let progress = min(1, date.timeIntervalSince(start) / InnerVault.holdDuration)
        charge = progress
        let bolts = min(InnerVault.boltCount, Int(progress * Double(InnerVault.boltCount) + 0.001))
        if bolts > retractedBolts {
            retractedBolts = bolts
            UIImpactFeedbackGenerator(style: bolts == InnerVault.boltCount ? .heavy : .rigid)
                .impactOccurred(intensity: 1)
        }
        if progress >= 1 {
            completeUnlock()
        }
    }

    private func completeUnlock() {
        finishing = true
        holding = false
        holdStartedAt = nil
        retractedBolts = InnerVault.boltCount
        charge = 1
        LogicStore.shared.unlockInnerVault()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            irisOpen = true
            bloom = 1
            glow = 0.85
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                revealed = true
            }
        }
    }

    private func stepKeys(_ delta: Int) {
        let next = adjustedKeys(from: keys, by: delta)
        guard next != keys else { return }
        keys = next
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onChanged()
    }

    private func stepKarma(_ delta: Int) {
        let next = adjustedKarma(from: karma, by: delta)
        guard next != karma else { return }
        karma = next
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onChanged()
    }
}

// MARK: - Steppers

private struct ReserveStepper: View {
    let title: String
    let icon: String
    let accent: Color
    let value: Int
    let canIncrement: Bool
    let canDecrement: Bool
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .labelStyle(.titleAndIcon)
                .textCase(.uppercase)
                .tracking(1)

            stepButton(systemName: "chevron.up", enabled: canIncrement, action: onIncrement)
                .accessibilityLabel("Increase \(title)")

            Text("\(value)")
                .font(.lockedNumber(44))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minHeight: 54)

            stepButton(systemName: "chevron.down", enabled: canDecrement, action: onDecrement)
                .accessibilityLabel("Decrease \(title)")
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(accent.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.bold))
                .foregroundStyle(enabled ? .white : .white.opacity(0.22))
                .frame(width: 56, height: 44)
                .background(enabled ? accent.opacity(0.22) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct IrisPetal: Shape {
    var count: Int
    var index: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 + 2
        let slice = 360.0 / Double(max(count, 1))
        let start = Angle.degrees(Double(index) * slice - 90)
        let end = Angle.degrees(Double(index + 1) * slice - 90)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}
