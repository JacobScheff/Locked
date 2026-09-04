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
                    Image(systemName: unlocked ? "lock.open.fill" : "lock.rotation")
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
                         : "Spin the combination to adjust Keys and Karma. Extreme use only.")
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
            : "Inner vault. Spin the combination, then adjust keys and karma.")
    }
}

// MARK: - Combination lock

struct InnerVaultView: View {
    var onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss

    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Double = 0.0

    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0

    @AppStorage("emergencyOverrideUntil", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var emergencyOverrideUntil: Double = 0

    @State private var combination = InnerVault.randomCombination()
    @State private var dialAngle = 0.0
    @State private var lastFingerAngle: Double?
    @State private var lastTick = 0
    @State private var step = 0
    @State private var travelInDirection = 0.0
    @State private var wrongWay = 0.0
    @State private var onTarget = false
    @State private var spinning = false
    @State private var retractedBolts = 0
    @State private var irisOpen = false
    @State private var finishing = false
    @State private var revealed = false
    @State private var glow = 0.28
    @State private var bloom = 0.0

    @State private var tickFeedback = UISelectionFeedbackGenerator()
    @State private var notchFeedback = UIImpactFeedbackGenerator(style: .rigid)
    @State private var catchFeedback = UIImpactFeedbackGenerator(style: .heavy)

    private var displayedKeys: Int { Int(clampKeys(keys).rounded(.towardZero)) }
    private var displayedKarma: Int { Int(clampKarma(karma).rounded(.towardZero)) }

    private var currentNumber: Int {
        InnerVault.number(at: dialAngle)
    }

    private var requiredClockwise: Bool {
        step % 2 == 0
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                if revealed {
                    treasury
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                } else {
                    lockedStage
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .interactiveDismissDisabled(!revealed)
        .onAppear(perform: prepare)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { date in
            if !EmergencyOverride.isActive(at: date) { dismiss() }
        }
        .onChange(of: emergencyOverrideUntil) { _, _ in
            if !EmergencyOverride.isActive() { dismiss() }
        }
    }

    // MARK: Stages

    private var lockedStage: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Inner vault")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.vaultBrass)
                    .tracking(2.4)
                    .textCase(.uppercase)

                Text(instruction)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            combinationReadout

            combinationDial
                .frame(width: 300, height: 300)

            dismissButton(title: "Cancel", prominent: false)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var instruction: String {
        guard step < combination.count else { return "Opening" }
        let number = combination[step]
        return requiredClockwise ? "Turn right to \(number)" : "Turn left to \(number)"
    }

    private var combinationReadout: some View {
        HStack(spacing: 14) {
            ForEach(Array(combination.enumerated()), id: \.offset) { index, number in
                Text(String(format: "%02d", number))
                    .font(.lockedNumber(22))
                    .foregroundStyle(index < step ? Color.lockedTeal : (index == step ? Color.vaultBrass : .white.opacity(0.28)))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(index == step ? Color.vaultBrass.opacity(0.14) : Color.white.opacity(0.05))
                    )
            }
        }
        .accessibilityLabel("Combination \(combination.map(String.init).joined(separator: ", "))")
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

            dismissButton(title: "Done", prominent: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Dial

    private var combinationDial: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.18, green: 0.20, blue: 0.23),
                                Color(red: 0.06, green: 0.07, blue: 0.08)
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: 160
                        )
                    )
                    .shadow(color: Color.lockedTeal.opacity(glow * (irisOpen ? 0.7 : 0.22)), radius: 26, y: 8)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.vaultBrass, Color.vaultBrass.opacity(0.35), Color.vaultBrass],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 8
                    )
                    .padding(10)

                dialFace
                    .rotationEffect(.degrees(dialAngle))

                ForEach(0..<combination.count, id: \.self) { index in
                    bolt(retracted: index < retractedBolts)
                        .rotationEffect(.degrees(Double(index) * 120 + 60))
                }

                Circle()
                    .fill(Color.lockedTeal.opacity(bloom * 0.5))
                    .blur(radius: 18)
                    .padding(78)
                    .opacity(irisOpen ? 1 : 0)

                iris
                    .padding(54)

                hub

                pointer
            }
            .contentShape(Circle())
            .gesture(spinGesture(in: size))
            .accessibilityLabel("Combination dial. Current number \(currentNumber).")
        }
    }

    private var dialFace: some View {
        ZStack {
            ForEach(0..<InnerVault.tickCount, id: \.self) { tick in
                let major = tick.isMultiple(of: 5)
                Capsule()
                    .fill(major ? Color.vaultBrass : Color.white.opacity(0.38))
                    .frame(width: major ? 3 : 1.5, height: major ? 16 : 9)
                    .offset(y: -128)
                    .rotationEffect(.degrees(Double(tick) * InnerVault.degreesPerTick))
            }

            ForEach(Array(stride(from: 0, to: InnerVault.tickCount, by: 5)), id: \.self) { number in
                Text("\(number)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.vaultBrass)
                    .offset(y: -106)
                    .rotationEffect(.degrees(Double(number) * InnerVault.degreesPerTick))
            }
        }
        .allowsHitTesting(false)
    }

    private var pointer: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(Color.vaultBrass)
                .frame(width: 16, height: 12)
            Capsule()
                .fill(Color.vaultBrass)
                .frame(width: 4, height: 10)
        }
        .offset(y: -142)
        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
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
            .frame(width: 14, height: 32)
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
            .offset(y: retracted ? -70 : -118)
            .opacity(retracted ? 0.18 : 1)
            .animation(.interpolatingSpring(stiffness: 260, damping: 16), value: retracted)
            .allowsHitTesting(false)
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
                        endRadius: 44
                    )
                )
            Circle()
                .stroke(Color.vaultBrass.opacity(spinning ? 0.95 : 0.5), lineWidth: 2)
            Text("\(currentNumber)")
                .font(.lockedNumber(28))
                .foregroundStyle(Color.vaultBrass)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .frame(width: 86, height: 86)
        .allowsHitTesting(false)
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

    private func dismissButton(title: String, prominent: Bool) -> some View {
        Button {
            dismiss()
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(prominent ? .black : .white.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background((prominent ? Color.vaultBrass : Color.white.opacity(0.1)), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(prominent ? Color.clear : Color.white.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: Interaction

    private func spinGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in spin(at: value.location, in: size) }
            .onEnded { _ in endSpin() }
    }

    private func prepare() {
        keys = clampKeys(keys)
        karma = clampKarma(karma)
        lastTick = currentNumber
        tickFeedback.prepare()
        notchFeedback.prepare()
        catchFeedback.prepare()
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glow = 0.55
        }
        if InnerVault.isUnlocked() {
            step = combination.count
            retractedBolts = combination.count
            finishing = true
            irisOpen = true
            bloom = 1
            revealed = true
        }
    }

    private func spin(at location: CGPoint, in size: CGSize) {
        guard !revealed, !finishing else { return }
        let angle = fingerAngle(at: location, in: size)
        guard let previous = lastFingerAngle else {
            lastFingerAngle = angle
            spinning = true
            return
        }

        var delta = angle - previous
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        lastFingerAngle = angle
        guard abs(delta) > 0.05 else { return }

        dialAngle += delta
        let tick = currentNumber
        if tick != lastTick {
            lastTick = tick
            playTick(for: tick)
        }

        let movingClockwise = delta > 0
        if movingClockwise == requiredClockwise {
            travelInDirection += abs(delta)
            wrongWay = 0
            onTarget = travelInDirection >= InnerVault.minimumTravel(for: step)
                && tick == combination[step]
        } else if onTarget {
            acceptStep()
            if !finishing {
                travelInDirection += abs(delta)
            }
        } else {
            wrongWay += abs(delta)
            onTarget = false
            if step > 0 && wrongWay >= InnerVault.resetWrongWay {
                resetCombination()
            }
        }
    }

    private func endSpin() {
        lastFingerAngle = nil
        spinning = false
        if onTarget {
            acceptStep()
        }
    }

    private func acceptStep() {
        onTarget = false
        retractedBolts = step + 1
        catchFeedback.impactOccurred(intensity: 1)
        travelInDirection = 0
        wrongWay = 0
        step += 1
        if step >= combination.count {
            completeUnlock()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func resetCombination() {
        step = 0
        retractedBolts = 0
        travelInDirection = 0
        wrongWay = 0
        onTarget = false
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func playTick(for number: Int) {
        if number.isMultiple(of: 5) {
            notchFeedback.impactOccurred(intensity: 0.85)
            notchFeedback.prepare()
        } else {
            tickFeedback.selectionChanged()
            tickFeedback.prepare()
        }
    }

    private func fingerAngle(at location: CGPoint, in size: CGSize) -> Double {
        let dx = location.x - size.width / 2
        let dy = location.y - size.height / 2
        return atan2(dy, dx) * 180 / .pi
    }

    private func completeUnlock() {
        finishing = true
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

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
