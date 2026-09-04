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
    @State private var shattered = false
    @State private var released = false
    @State private var flash = 0.0
    @State private var shake: CGFloat = 0
    @State private var glow = 0.35
    @State private var instructionPulse = false

    private let needed = EmergencyOverride.strikesToBreak

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        warningCopy
                        glassBox
                        strikeMeter
                            .padding(.top, 8)
                        footerCopy
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                    .offset(x: shake)
                }
            }

            if released {
                Color.black.opacity(0.78)
                    .ignoresSafeArea()
                    .transition(.opacity)
                releasedOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
    }

    // MARK: Layers

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color.hazardRed.opacity(shattered ? 0.45 : 0.22),
                    Color.black
                ],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .animation(.easeIn(duration: 0.6), value: shattered)
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

                if !shattered {
                    Color.white.opacity(flash)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .gesture(strikeGesture(in: size))
        }
        .aspectRatio(0.78, contentMode: .fit)
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity)
    }

    private func glassPane(in size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.66, blue: 0.78).opacity(0.45),
                    Color(red: 0.22, green: 0.28, blue: 0.36).opacity(0.55),
                    Color(red: 0.62, green: 0.72, blue: 0.82).opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [.white.opacity(0.28), .clear, .white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)

            if !shattered {
                paneLettering
                    .padding(20)

                Canvas { context, canvasSize in
                    for crack in cracks {
                        crack.draw(in: &context, size: canvasSize)
                    }
                }
                .allowsHitTesting(false)
            } else {
                GeometryReader { pane in
                    ForEach(shards) { shard in
                        shard.path(in: pane.size)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.28 * shard.opacity),
                                        Color.cyan.opacity(0.12 * shard.opacity)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                shard.path(in: pane.size)
                                    .stroke(Color.white.opacity(0.45 * shard.opacity), lineWidth: 0.8)
                            )
                            .offset(shard.drift)
                            .rotationEffect(Angle.degrees(shard.rotation))
                            .opacity(shard.opacity)
                    }
                }
            }
        }
    }

    private var paneLettering: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color.hazardRed.opacity(0.9))

            Text("In case of\nemergency")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.72, green: 0.08, blue: 0.14))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Break glass")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(instructionPulse ? 0.95 : 0.45))
                .tracking(3)
                .textCase(.uppercase)

            Text("Releases all locks for 60 minutes")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private var strikeMeter: some View {
        HStack(spacing: 10) {
            ForEach(0..<needed, id: \.self) { index in
                Capsule()
                    .fill(index < strikes ? Color.hazardYellow : Color.white.opacity(0.18))
                    .frame(width: 42, height: 6)
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
                    .fill(Color.hazardYellow.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(Color.hazardYellow)
                    .symbolEffect(.bounce.up, value: released)
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

    private func strikeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard !shattered else { return }
                strike(at: value.location, in: size)
            }
    }

    private func strike(at location: CGPoint, in size: CGSize) {
        let pane = CGRect(x: 10, y: 26, width: size.width - 20, height: size.height - 52)
        let local = CGPoint(
            x: (location.x - pane.minX) / max(pane.width, 1),
            y: (location.y - pane.minY) / max(pane.height, 1)
        )
        let origin = CGPoint(
            x: min(max(local.x, 0.08), 0.92),
            y: min(max(local.y, 0.08), 0.92)
        )

        cracks.append(GlassCrack.spider(from: origin, seed: strikes))

        strikes += 1
        flashImpact()
        haptic(for: strikes)

        if strikes >= needed {
            shatter()
        }
    }

    private func flashImpact() {
        flash = 0.55
        shake = strikes == needed ? 14 : 8
        withAnimation(.easeOut(duration: 0.18)) { flash = 0 }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { shake = 0 }
    }

    private func haptic(for count: Int) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = count >= needed ? .heavy : .rigid
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: min(1.0, 0.55 + 0.2 * CGFloat(count)))
        if count >= needed {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func shatter() {
        shattered = true
        LogicStore.shared.activateEmergencyOverride()
        onReleased()

        withAnimation(.easeIn(duration: 0.55)) {
            for index in shards.indices {
                shards[index].drift = CGSize(
                    width: CGFloat.random(in: -120...120),
                    height: CGFloat.random(in: 160...380)
                )
                shards[index].rotation = Double.random(in: -40...40)
                shards[index].opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                released = true
            }
        }
    }
}

// MARK: - Drawing helpers

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

struct GlassCrack {
    var branches: [[CGPoint]]

    static func spider(from origin: CGPoint, seed: Int) -> GlassCrack {
        var rng = SeededRandom(seed: seed &* 7919 &+ Int(origin.x * 1000) &+ Int(origin.y * 100))
        var branches: [[CGPoint]] = []
        let armCount = 5 + seed * 2
        for i in 0..<armCount {
            let base = (Double(i) / Double(armCount)) * .pi * 2 + rng.next() * 0.4
            var points = [origin]
            var current = origin
            var angle = base
            let steps = 4 + seed
            for _ in 0..<steps {
                angle += (rng.next() - 0.5) * 0.9
                let length = 0.06 + rng.next() * 0.16
                current = CGPoint(
                    x: current.x + CGFloat(cos(angle) * length),
                    y: current.y + CGFloat(sin(angle) * length)
                )
                points.append(current)
            }
            branches.append(points)

            if rng.next() > 0.45 {
                let forkOrigin = points[points.count / 2]
                var fork = [forkOrigin]
                var forkPoint = forkOrigin
                var forkAngle = angle + (rng.next() > 0.5 ? 0.7 : -0.7)
                for _ in 0..<3 {
                    forkAngle += (rng.next() - 0.5) * 0.6
                    let length = 0.05 + rng.next() * 0.1
                    forkPoint = CGPoint(
                        x: forkPoint.x + CGFloat(cos(forkAngle) * length),
                        y: forkPoint.y + CGFloat(sin(forkAngle) * length)
                    )
                    fork.append(forkPoint)
                }
                branches.append(fork)
            }
        }
        return GlassCrack(branches: branches)
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        for branch in branches {
            guard branch.count > 1 else { continue }
            var path = Path()
            path.move(to: CGPoint(x: branch[0].x * size.width, y: branch[0].y * size.height))
            for point in branch.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
            }
            context.stroke(path, with: .color(.white.opacity(0.92)), style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(.black.opacity(0.25)), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
        }
    }
}

struct GlassShard: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var drift: CGSize = .zero
    var rotation: Double = 0
    var opacity: Double = 1

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
        let polygons: [[CGPoint]] = [
            [CGPoint(x: 0, y: 0), CGPoint(x: 0.38, y: 0), CGPoint(x: 0.22, y: 0.36), CGPoint(x: 0, y: 0.28)],
            [CGPoint(x: 0.38, y: 0), CGPoint(x: 0.72, y: 0), CGPoint(x: 0.6, y: 0.3), CGPoint(x: 0.22, y: 0.36)],
            [CGPoint(x: 0.72, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 0.34), CGPoint(x: 0.6, y: 0.3)],
            [CGPoint(x: 0, y: 0.28), CGPoint(x: 0.22, y: 0.36), CGPoint(x: 0.18, y: 0.7), CGPoint(x: 0, y: 0.66)],
            [CGPoint(x: 0.22, y: 0.36), CGPoint(x: 0.6, y: 0.3), CGPoint(x: 0.55, y: 0.68), CGPoint(x: 0.18, y: 0.7)],
            [CGPoint(x: 0.6, y: 0.3), CGPoint(x: 1, y: 0.34), CGPoint(x: 1, y: 0.7), CGPoint(x: 0.55, y: 0.68)],
            [CGPoint(x: 0, y: 0.66), CGPoint(x: 0.18, y: 0.7), CGPoint(x: 0.32, y: 1), CGPoint(x: 0, y: 1)],
            [CGPoint(x: 0.18, y: 0.7), CGPoint(x: 0.55, y: 0.68), CGPoint(x: 0.7, y: 1), CGPoint(x: 0.32, y: 1)],
            [CGPoint(x: 0.55, y: 0.68), CGPoint(x: 1, y: 0.7), CGPoint(x: 1, y: 1), CGPoint(x: 0.7, y: 1)]
        ]
        return polygons.map { GlassShard(points: $0) }
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
