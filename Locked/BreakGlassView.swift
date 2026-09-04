import SwiftUI
import UIKit

// MARK: - Home: dormant seal

struct EmergencySealCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HazardStripeBar()
                    .frame(height: 10)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: LockedTheme.cardRadius,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: LockedTheme.cardRadius,
                            style: .continuous
                        )
                    )

                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.hazardRed.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.hazardRed.opacity(0.35), lineWidth: 1)
                            )
                        Image(systemName: "light.beacon.max.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.hazardRed)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("In case of emergency")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Color.hazardRed)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        Text("Break the glass to release every lock for one hour. Extreme use only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.hazardRed.opacity(0.6))
                }
                .padding(16)
            }
            .background(LockedCardBackground())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Emergency override. Break glass to release all locks for one hour.")
    }
}

// MARK: - Home: active override

struct OverrideStatusBanner: View {
    @AppStorage("emergencyOverrideUntil", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var emergencyOverrideUntil: Double = 0

    var onRestore: () -> Void
    var onExpired: () -> Void = {}

    @State private var confirmRestore = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Date(timeIntervalSince1970: emergencyOverrideUntil).timeIntervalSince(context.date)
            if remaining > 0 {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.open.fill")
                            .font(.title2)
                            .foregroundStyle(Color.hazardYellow)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Seal broken")
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(.white)
                            Text("Locks are suspended. They return automatically.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer()
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(EmergencyOverride.formatRemaining(remaining))
                            .font(.lockedNumber(34))
                            .foregroundStyle(Color.hazardYellow)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("remaining")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Button {
                        confirmRestore = true
                    } label: {
                        Text("Restore locks now")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.42, green: 0.07, blue: 0.10),
                                    Color(red: 0.18, green: 0.05, blue: 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color.hazardYellow.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: Color.hazardRed.opacity(0.35), radius: 18, y: 8)
                }
                .alert("Restore locks?", isPresented: $confirmRestore) {
                    Button("Keep them released", role: .cancel) { }
                    Button("Restore now", role: .destructive) {
                        LogicStore.shared.endEmergencyOverride()
                        onRestore()
                    }
                } message: {
                    Text("Locked apps will start bouncing you out again immediately.")
                }
            } else {
                Color.clear
                    .frame(height: 0)
                    .onAppear(perform: onExpired)
            }
        }
    }
}

// MARK: - Break glass ritual

struct BreakGlassView: View {
    var onReleased: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var strikes = 0
    @State private var cracks: [GlassCrack] = []
    @State private var shards: [GlassShard] = GlassShard.makeSet()
    @State private var debris: [GlassDebris] = []
    @State private var ripples: [ImpactRipple] = []
    @State private var shattered = false
    @State private var released = false
    @State private var flash = 0.0
    @State private var burstFlash = 0.0
    @State private var shake: CGFloat = 0
    @State private var shakeY: CGFloat = 0
    @State private var paneScale: CGFloat = 1
    @State private var glow = 0.35
    @State private var instructionPulse = false
    @State private var impactPoint = CGPoint(x: 0.5, y: 0.45)
    @State private var letteringBreak: CGFloat = 0
    @State private var keyTurn: Double = 0
    @State private var keyScale: CGFloat = 1
    @State private var keyGlow: Double = 0.4
    @State private var keyUnlocked = false
    @State private var shackleOpen = false
    @State private var keySpin: Double = 0
    @State private var spinTick = 0

    private let needed = EmergencyOverride.strikesToBreak

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                VStack(spacing: 18) {
                    warningCopy
                    glassBox
                    strikeMeter
                    footerCopy
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
            .opacity(released ? 0.08 : 1)

            Color.white.opacity(burstFlash)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if released {
                releasedOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .interactiveDismissDisabled(shattered)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = 0.7
                instructionPulse = true
            }
        }
        .onDisappear {
            spinTick = 0
        }
        .onReceive(Timer.publish(every: 0.65, on: .main, in: .common).autoconnect()) { _ in
            guard keyUnlocked else { return }
            spinTick += 1
            let generator = UIImpactFeedbackGenerator(style: spinTick.isMultiple(of: 4) ? .medium : .rigid)
            generator.impactOccurred(intensity: spinTick.isMultiple(of: 4) ? 0.95 : 0.7)
        }
    }

    // MARK: Layers

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color.hazardRed.opacity(shattered ? 0.55 : 0.22),
                    Color.black
                ],
                center: .center,
                startRadius: 10,
                endRadius: 460
            )
            .animation(.easeIn(duration: 0.45), value: shattered)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            if !shattered {
                Button("Cancel") { dismiss() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .frame(height: 44)
    }

    private var warningCopy: some View {
        VStack(spacing: 8) {
            Text("Extreme use only")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.hazardYellow)
                .tracking(2.4)
                .textCase(.uppercase)

            Text(shattered ? "Seal breaking" : "This will release every locked app.")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .opacity(released ? 0 : 1)
    }

    private var glassBox: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 2)
                    )
                    .shadow(color: Color.hazardRed.opacity(glow * 0.55), radius: 30, y: 10)

                interior(size: size)

                fxLayer(size: size)

                if !shattered {
                    Color.white.opacity(flash)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(paneScale)
            .offset(x: shake, y: shakeY)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .gesture(strikeGesture(in: size))
        }
        .aspectRatio(0.78, contentMode: .fit)
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity)
    }

    private func interior(size: CGSize) -> some View {
        VStack(spacing: 0) {
            HazardStripeBar()
                .frame(height: 16)
            Rectangle()
                .fill(Color(red: 0.18, green: 0.18, blue: 0.19))
                .frame(height: 10)
            glassPane(in: size)
            Rectangle()
                .fill(Color(red: 0.18, green: 0.18, blue: 0.19))
                .frame(height: 10)
            HazardStripeBar()
                .frame(height: 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(10)
    }

    private func glassPane(in size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.07, blue: 0.04),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            sealedPrize

            if shattered {
                RadialGradient(
                    colors: [Color.hazardYellow.opacity(0.22), .clear],
                    center: .center,
                    startRadius: 8,
                    endRadius: 170
                )
                .allowsHitTesting(false)
            } else {
                Color.white.opacity(0.10)

                LinearGradient(
                    colors: [
                        Color(red: 0.62, green: 0.74, blue: 0.86).opacity(0.58),
                        Color(red: 0.28, green: 0.36, blue: 0.46).opacity(0.62),
                        Color(red: 0.70, green: 0.80, blue: 0.90).opacity(0.40)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [.white.opacity(0.34), .clear, .white.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)

                paneLettering
                    .padding(18)
                    .blur(radius: letteringBreak * 1.2)
                    .opacity(1 - letteringBreak * 0.4)

                Canvas { context, canvasSize in
                    for crack in cracks {
                        crack.draw(in: &context, size: canvasSize)
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var sealedPrize: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.hazardYellow.opacity(keyUnlocked ? 0.42 : 0.14 + 0.06 * Double(strikes)),
                            Color.orange.opacity(keyUnlocked ? 0.12 : 0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 118
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(instructionPulse && !keyUnlocked ? 1.05 : 1)

            Image(systemName: shackleOpen ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 78, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(shackleOpen ? 0.55 : 0.14),
                            Color.white.opacity(shackleOpen ? 0.22 : 0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: shattered ? 0 : 1.8)
                .opacity(shattered ? 1 : 0.45)
                .shadow(color: .black.opacity(0.55), radius: 8, y: 6)
                .offset(x: shackleOpen ? 10 : 0, y: 20)
                .animation(.spring(response: 0.42, dampingFraction: 0.62), value: shackleOpen)

            SculptedKey()
                .scaleEffect((shattered ? keyScale : 0.86) * (instructionPulse && !shattered ? 1.02 : 1))
                .rotationEffect(Angle.degrees(-40 + keyTurn + keySpin))
                .rotation3DEffect(
                    Angle.degrees(shattered ? 9 : 14),
                    axis: (x: 0.85, y: 0.18, z: 0),
                    perspective: 0.32
                )
                .offset(y: keyUnlocked ? -8 : 6)
                .blur(radius: shattered ? 0 : 2.2)
                .saturation(shattered ? 1 : 0.55)
                .opacity(shattered ? 1 : 0.38)
                .shadow(color: Color.hazardYellow.opacity(shattered ? keyGlow * 0.55 : 0.12), radius: shattered ? 14 : 4, y: 4)
        }
        .allowsHitTesting(false)
    }

    private func fxLayer(size: CGSize) -> some View {
        let pane = paneRect(in: size)
        return ZStack {
            ForEach(ripples) { ripple in
                Circle()
                    .stroke(
                        Color.white.opacity((1 - ripple.progress) * 0.85),
                        lineWidth: 3 - ripple.progress * 2
                    )
                    .frame(
                        width: 18 + ripple.progress * pane.width * 0.85,
                        height: 18 + ripple.progress * pane.width * 0.85
                    )
                    .position(
                        x: pane.minX + ripple.origin.x * pane.width,
                        y: pane.minY + ripple.origin.y * pane.height
                    )
                    .blendMode(.screen)
            }

            if shattered {
                ForEach(shards) { shard in
                    shard.path(in: pane.size)
                        .fill(shard.fill)
                        .overlay(
                            shard.path(in: pane.size)
                                .stroke(Color.white.opacity(0.55 * shard.opacity), lineWidth: 0.9)
                        )
                        .frame(width: pane.width, height: pane.height)
                        .position(x: pane.midX, y: pane.midY)
                        .offset(shard.drift)
                        .rotationEffect(Angle.degrees(shard.rotation))
                        .opacity(shard.opacity)
                        .shadow(color: .white.opacity(0.25 * shard.opacity), radius: 6)
                }
            }

            ForEach(debris) { speck in
                Capsule()
                    .fill(speck.spark ? Color.white : Color.white.opacity(0.7))
                    .frame(width: speck.size, height: speck.spark ? speck.size : speck.size * 0.35)
                    .rotationEffect(Angle.degrees(speck.rotation))
                    .position(
                        x: pane.minX + speck.origin.x * pane.width,
                        y: pane.minY + speck.origin.y * pane.height
                    )
                    .offset(speck.drift)
                    .opacity(speck.opacity)
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
    }

    private var paneLettering: some View {
        VStack(spacing: 6) {
            Text("In case of emergency")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.72, green: 0.08, blue: 0.14))
                .textCase(.uppercase)
                .tracking(1.2)
                .multilineTextAlignment(.center)

            Spacer()

            Text("Break glass")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(instructionPulse ? 0.95 : 0.45))
                .tracking(3)
                .textCase(.uppercase)

            Text("Releases all locks for 60 minutes")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    private var strikeMeter: some View {
        HStack(spacing: 10) {
            ForEach(0..<needed, id: \.self) { index in
                Capsule()
                    .fill(index < strikes ? Color.hazardYellow : Color.white.opacity(0.18))
                    .frame(width: 42, height: 6)
                    .scaleEffect(index == strikes - 1 ? 1.18 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: strikes)
            }
        }
        .opacity(released ? 0 : 1)
        .overlay(alignment: .bottom) {
            Text(strikes == 0 ? "Strike the glass" : (shattered ? " " : "\(needed - strikes) more"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.45))
                .offset(y: 18)
        }
        .padding(.bottom, 10)
    }

    private var footerCopy: some View {
        Text("Does not spend Keys or change Karma. Locks return on their own. This is not an unlock — it is a temporary breach.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
    }

    private var releasedOverlay: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.hazardYellow.opacity(0.16))
                    .frame(width: 150, height: 150)
                Circle()
                    .stroke(Color.hazardYellow.opacity(0.35), lineWidth: 2)
                    .frame(width: 168, height: 168)
                SculptedKey()
                    .rotationEffect(Angle.degrees(-40 + keyTurn + keySpin))
                    .rotation3DEffect(
                        Angle.degrees(9),
                        axis: (x: 0.85, y: 0.18, z: 0),
                        perspective: 0.32
                    )
            }

            VStack(spacing: 8) {
                Text("Seal broken")
                    .font(.lockedTitle(34))
                    .foregroundStyle(.white)
                Text("Every lock is suspended for one hour.\nThey will snap back when the timer ends.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.hazardYellow)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 36)
            .padding(.top, 8)
        }
        .padding(28)
    }

    // MARK: Interaction

    private func paneRect(in size: CGSize) -> CGRect {
        CGRect(x: 10, y: 36, width: max(size.width - 20, 1), height: max(size.height - 72, 1))
    }

    private func strikeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard !shattered else { return }
                strike(at: value.location, in: size)
            }
    }

    private func strike(at location: CGPoint, in size: CGSize) {
        let pane = paneRect(in: size)
        let local = CGPoint(
            x: (location.x - pane.minX) / pane.width,
            y: (location.y - pane.minY) / pane.height
        )
        let origin = CGPoint(
            x: min(max(local.x, 0.08), 0.92),
            y: min(max(local.y, 0.08), 0.92)
        )
        impactPoint = origin

        cracks.append(GlassCrack.spider(from: origin, seed: strikes, intensity: strikes + 1))
        if strikes >= 1 {
            cracks.append(GlassCrack.edgeStress(from: origin, seed: strikes + 17))
        }

        spawnRipple(at: origin)
        spawnDebris(at: origin, count: 10 + strikes * 6, exploding: false)

        strikes += 1
        flashImpact(final: strikes >= needed)
        haptic(for: strikes)

        withAnimation(.easeOut(duration: 0.35)) {
            letteringBreak = CGFloat(strikes) / CGFloat(needed)
            keyGlow = 0.4 + Double(strikes) * 0.18
        }

        if strikes >= needed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                shatter()
            }
        }
    }

    private func flashImpact(final: Bool) {
        flash = final ? 0.9 : 0.55
        paneScale = final ? 0.94 : 0.97
        shake = final ? 16 : 9
        shakeY = final ? -10 : -5
        withAnimation(.easeOut(duration: 0.16)) { flash = 0 }
        withAnimation(.interpolatingSpring(stiffness: 280, damping: 16)) {
            paneScale = 1
            shake = 0
            shakeY = 0
        }
    }

    private func haptic(for count: Int) {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        }
        if count >= needed {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            }
        }
    }

    private func spawnRipple(at origin: CGPoint) {
        let ripple = ImpactRipple(origin: origin)
        ripples.append(ripple)
        let id = ripple.id
        withAnimation(.easeOut(duration: 0.55)) {
            if let index = ripples.firstIndex(where: { $0.id == id }) {
                ripples[index].progress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ripples.removeAll { $0.id == id }
        }
    }

    private func spawnDebris(at origin: CGPoint, count: Int, exploding: Bool) {
        var additions: [GlassDebris] = []
        var flights: [(drift: CGSize, rotation: Double)] = []
        for index in 0..<count {
            let angle = Double(index) / Double(max(count, 1)) * .pi * 2 + Double.random(in: -0.3...0.3)
            let speed = exploding ? CGFloat.random(in: 90...240) : CGFloat.random(in: 18...70)
            additions.append(
                GlassDebris(
                    origin: origin,
                    size: exploding ? CGFloat.random(in: 2...7) : CGFloat.random(in: 1.5...4),
                    spark: index.isMultiple(of: 3)
                )
            )
            flights.append((
                CGSize(
                    width: CGFloat(cos(angle)) * speed,
                    height: CGFloat(sin(angle)) * speed * (exploding ? 0.85 : 0.55) + (exploding ? CGFloat.random(in: 40...140) : 0)
                ),
                Double.random(in: -80...80)
            ))
        }
        let start = debris.count
        debris.append(contentsOf: additions)
        withAnimation(.easeOut(duration: exploding ? 0.9 : 0.45)) {
            for offset in flights.indices {
                debris[start + offset].drift = flights[offset].drift
                debris[start + offset].rotation = flights[offset].rotation
                debris[start + offset].opacity = 0
            }
        }
    }

    private func shatter() {
        shattered = true
        LogicStore.shared.activateEmergencyOverride()
        onReleased()

        burstFlash = 0.92
        paneScale = 1.04
        withAnimation(.easeOut(duration: 0.45)) {
            burstFlash = 0
            paneScale = 1
        }

        spawnDebris(at: impactPoint, count: 28, exploding: true)
        spawnRipple(at: impactPoint)

        for index in shards.indices {
            let center = shards[index].centroid
            let dx = center.x - impactPoint.x
            let dy = center.y - impactPoint.y
            let dist = max(0.04, hypot(dx, dy))
            let push = 140 + dist * 280
            let delay = dist * 0.22
            let fall = 220 + CGFloat.random(in: 40...180)

            withAnimation(.easeIn(duration: 0.62 + dist * 0.4).delay(delay)) {
                shards[index].drift = CGSize(
                    width: (dx / dist) * push + CGFloat.random(in: -30...30),
                    height: (dy / dist) * (push * 0.45) + fall
                )
                shards[index].rotation = Double.random(in: -70...70)
                shards[index].opacity = 0
            }
        }

        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred(intensity: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.62)) {
                keyTurn = 95
                keyScale = 1.12
                keyGlow = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.58)) {
                shackleOpen = true
                keyUnlocked = true
                keyScale = 1.18
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                keySpin = 360
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                released = true
            }
        }
    }
}

// MARK: - Drawing helpers

private struct SculptedKey: View {
    var body: some View {
        ZStack {
            Image(systemName: "key.fill")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(Color(red: 0.32, green: 0.16, blue: 0.02))
                .offset(x: 5, y: 7)

            Image(systemName: "key.fill")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(Color(red: 0.78, green: 0.46, blue: 0.08))
                .offset(x: 2.5, y: 3.5)

            Image(systemName: "key.fill")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.97, blue: 0.78),
                            Color.hazardYellow,
                            Color(red: 0.86, green: 0.52, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 96, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white.opacity(0.65), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.6), radius: 8, y: 7)
        .shadow(color: Color.hazardYellow.opacity(0.3), radius: 10, y: 1)
    }
}

struct HazardStripeBar: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let stripe: CGFloat = 12
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + stripe, y: 0))
                path.addLine(to: CGPoint(x: x + stripe + size.height, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(Color.hazardYellow))
                x += stripe * 2
            }
        }
        .accessibilityHidden(true)
    }
}

struct ImpactRipple: Identifiable {
    let id = UUID()
    var origin: CGPoint
    var progress: CGFloat = 0.02
}

struct GlassDebris: Identifiable {
    let id = UUID()
    var origin: CGPoint
    var drift: CGSize = .zero
    var rotation: Double = 0
    var opacity: Double = 1
    var size: CGFloat
    var spark: Bool
}

struct GlassCrack {
    var branches: [[CGPoint]]
    var weight: CGFloat

    static func spider(from origin: CGPoint, seed: Int, intensity: Int) -> GlassCrack {
        var rng = SeededRandom(seed: seed &* 7919 &+ Int(origin.x * 1000) &+ Int(origin.y * 100))
        var branches: [[CGPoint]] = []
        let armCount = 6 + intensity * 3
        for i in 0..<armCount {
            let base = (Double(i) / Double(armCount)) * .pi * 2 + rng.next() * 0.35
            var points = [origin]
            var current = origin
            var angle = base
            let steps = 5 + intensity * 2
            for _ in 0..<steps {
                angle += (rng.next() - 0.5) * 0.85
                let length = 0.07 + rng.next() * (0.12 + Double(intensity) * 0.04)
                current = CGPoint(
                    x: current.x + CGFloat(cos(angle) * length),
                    y: current.y + CGFloat(sin(angle) * length)
                )
                points.append(current)
            }
            branches.append(points)

            if rng.next() > 0.35 {
                let forkOrigin = points[max(1, points.count / 2)]
                var fork = [forkOrigin]
                var forkPoint = forkOrigin
                var forkAngle = angle + (rng.next() > 0.5 ? 0.8 : -0.8)
                for _ in 0..<(2 + intensity) {
                    forkAngle += (rng.next() - 0.5) * 0.55
                    let length = 0.05 + rng.next() * 0.11
                    forkPoint = CGPoint(
                        x: forkPoint.x + CGFloat(cos(forkAngle) * length),
                        y: forkPoint.y + CGFloat(sin(forkAngle) * length)
                    )
                    fork.append(forkPoint)
                }
                branches.append(fork)
            }
        }
        return GlassCrack(branches: branches, weight: 0.9 + CGFloat(intensity) * 0.35)
    }

    static func edgeStress(from origin: CGPoint, seed: Int) -> GlassCrack {
        var rng = SeededRandom(seed: seed)
        let edges = [
            CGPoint(x: origin.x, y: 0),
            CGPoint(x: origin.x, y: 1),
            CGPoint(x: 0, y: origin.y),
            CGPoint(x: 1, y: origin.y)
        ]
        var branches: [[CGPoint]] = []
        for edge in edges {
            var points = [origin]
            var current = origin
            let steps = 4
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                current = CGPoint(
                    x: origin.x + (edge.x - origin.x) * t + CGFloat(rng.next() - 0.5) * 0.05,
                    y: origin.y + (edge.y - origin.y) * t + CGFloat(rng.next() - 0.5) * 0.05
                )
                points.append(current)
            }
            branches.append(points)
        }
        return GlassCrack(branches: branches, weight: 1.1)
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        for branch in branches {
            guard branch.count > 1 else { continue }
            var path = Path()
            path.move(to: CGPoint(x: branch[0].x * size.width, y: branch[0].y * size.height))
            for point in branch.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
            }
            context.stroke(
                path,
                with: .color(.white.opacity(0.25)),
                style: StrokeStyle(lineWidth: weight + 2.2, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                path,
                with: .color(.white.opacity(0.92)),
                style: StrokeStyle(lineWidth: weight, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                path,
                with: .color(.black.opacity(0.28)),
                style: StrokeStyle(lineWidth: 0.45, lineCap: .round)
            )
        }
    }
}

struct GlassShard: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var drift: CGSize = .zero
    var rotation: Double = 0
    var opacity: Double = 1

    var centroid: CGPoint {
        let count = CGFloat(max(points.count, 1))
        return CGPoint(
            x: points.reduce(0) { $0 + $1.x } / count,
            y: points.reduce(0) { $0 + $1.y } / count
        )
    }

    var fill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.34 * opacity),
                Color(red: 0.55, green: 0.72, blue: 0.88).opacity(0.18 * opacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func path(in size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
        }
        path.closeSubpath()
        return path
    }

    static func makeSet() -> [GlassShard] {
        let cols = 4
        let rows = 5
        var rng = SeededRandom(seed: 42)
        var nodes: [[CGPoint]] = []
        for row in 0...rows {
            var line: [CGPoint] = []
            for col in 0...cols {
                let onEdge = row == 0 || row == rows || col == 0 || col == cols
                let jitterX = onEdge ? 0 : CGFloat(rng.next() - 0.5) * 0.12
                let jitterY = onEdge ? 0 : CGFloat(rng.next() - 0.5) * 0.10
                line.append(
                    CGPoint(
                        x: CGFloat(col) / CGFloat(cols) + jitterX,
                        y: CGFloat(row) / CGFloat(rows) + jitterY
                    )
                )
            }
            nodes.append(line)
        }

        var shards: [GlassShard] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let topLeft = nodes[row][col]
                let topRight = nodes[row][col + 1]
                let bottomRight = nodes[row + 1][col + 1]
                let bottomLeft = nodes[row + 1][col]
                if rng.next() > 0.5 {
                    shards.append(GlassShard(points: [topLeft, topRight, bottomRight]))
                    shards.append(GlassShard(points: [topLeft, bottomRight, bottomLeft]))
                } else {
                    shards.append(GlassShard(points: [topLeft, topRight, bottomLeft]))
                    shards.append(GlassShard(points: [topRight, bottomRight, bottomLeft]))
                }
            }
        }
        return shards
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(truncatingIfNeeded: seed == 0 ? 1 : seed)
    }

    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= (z >> 31)
        return Double(z % 10_000) / 10_000.0
    }
}
