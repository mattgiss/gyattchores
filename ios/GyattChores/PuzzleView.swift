import SwiftUI
import GyattCore

/// How long the frame holds still between the last hit and the level-up surge.
private let freezeSeconds = 0.30

/// One shard of a burst. Positions in board points, speeds in points a second.
private struct Shard {
    let x, y, vx, vy, size, born, life, spin: Double
    let color: Color
}

/// A ring of light spreading out from an impact.
private struct Ring {
    let x, y, born, speed: Double
}

private var clock: Double { Date().timeIntervalSinceReferenceDate }

/// The reward puzzle, "CLEAR THE GRID". Tap a block, then a block of the other colour in line with
/// it and nothing between: the first flies into the second and both shatter. Clear the board to
/// level up — the last hit freezes the frame for a beat, then the screen flashes, shakes and the new
/// level slams in, timed to the phone's strongest haptics.
struct PuzzleView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    /// Reduce Motion turns off the shake, the jitter and the big flash.
    @Environment(\.accessibilityReduceMotion) private var calm
    let player: Player

    @State private var level = 1
    @State private var board = PuzzleBoard(width: 1, height: 1, cells: ".")
    @State private var loaded = false
    @State private var selected: Int?
    @State private var busy = false
    @State private var flyFrom: Int?
    @State private var flyTo: Int?
    @State private var flyDone = false
    @State private var frozen = false
    @State private var celebrating = false
    @State private var clearedCount = 0
    @State private var missCell: Int?
    @State private var missTrigger = 0
    @State private var shards: [Shard] = []
    @State private var rings: [Ring] = []
    @State private var flash = 0.0
    @State private var zoom = 1.0
    @State private var shakeTrigger = 0
    @State private var shakeStrength = 0.0
    @State private var cell: CGFloat = 40

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Text(hint)
                    .font(.footnote).foregroundStyle(board.stuck ? Theme.bad : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.bottom, 4)
                GeometryReader { geo in
                    let size = min(geo.size.width / CGFloat(board.width), geo.size.height / CGFloat(board.height), 72)
                    boardView(size)
                        .frame(width: size * CGFloat(board.width), height: size * CGFloat(board.height))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .onAppear { cell = size }
                        .onChange(of: size) { _, s in cell = s }
                }
                .padding(20)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(board.blocksLeft) blocks left").foregroundStyle(.secondary)
                    if board.stuck && !busy { TermButton(label: "RESTART LEVEL") { restart() } }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .keyframeAnimator(initialValue: 0.0, trigger: shakeTrigger) { content, k in
                content.offset(x: CGFloat(k * shakeStrength), y: CGFloat(-k * shakeStrength * 0.6))
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1.0, duration: 0.032)
                    LinearKeyframe(-0.85, duration: 0.032)
                    LinearKeyframe(0.7, duration: 0.032)
                    LinearKeyframe(-0.55, duration: 0.032)
                    LinearKeyframe(0.4, duration: 0.032)
                    LinearKeyframe(-0.25, duration: 0.032)
                    LinearKeyframe(0.12, duration: 0.032)
                    LinearKeyframe(0.0, duration: 0.032)
                }
            }
            // The flash, in the app's pink.
            Theme.accent.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
            if celebrating {
                LevelUpCard(level: level + 1, cleared: clearedCount, calm: calm,
                            onNext: nextLevel, onBack: { fb.tap(); dismiss() })
                    .transition(.opacity)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            level = store.puzzleLevel(player.id)
            board = store.puzzlePack.board(level)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("← back") { fb.tap(); dismiss() }.accessibilityIdentifier("puzzle-back")
            Text("CLEAR THE GRID").font(.caption).kerning(3).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
            Spacer()
            Text("LVL \(level)").font(.headline).foregroundStyle(Theme.accent)
            Button("restart") { restart() }.disabled(busy || celebrating)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private var hint: String {
        if board.stuck { return "no moves left — the order matters. restart and try another way." }
        if let s = selected { return "now tap a \(board.cells[s] == .pink ? "black" : "pink") block in line with it" }
        return "tap a block, then one of the other colour in line with it. clear them all."
    }

    // MARK: Board

    private func center(_ i: Int, _ size: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(board.column(i)) + 0.5) * size, y: (CGFloat(board.row(i)) + 0.5) * size)
    }

    private func boardView(_ size: CGFloat) -> some View {
        let targets = Set(selected.map { board.targets(from: $0) } ?? [])
        return ZStack(alignment: .topLeading) {
            // Tapping between blocks puts down the one in hand.
            Color.clear.contentShape(Rectangle()).onTapGesture { if !busy { selected = nil } }
            ForEach(board.cells.indices, id: \.self) { i in
                cellView(i, size, isTarget: targets.contains(i))
            }
            if let from = flyFrom, let to = flyTo {
                BlockTile(color: board.cells[from] == .pink ? Theme.accent : .primary, size: size, selected: false, target: false)
                    .shadow(color: Theme.accent.opacity(0.8), radius: 10)
                    .position(flyDone ? center(to, size) : center(from, size))
                if frozen {
                    // The moment of impact, held: a white-hot core in a pink halo.
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.55)).frame(width: size * 2.2, height: size * 2.2)
                        Circle().fill(Color.white).frame(width: size * 1.1, height: size * 1.1)
                    }
                    .position(center(to, size))
                    .allowsHitTesting(false)
                }
            }
            TimelineView(.animation(paused: shards.isEmpty && rings.isEmpty)) { tl in
                Canvas { ctx, _ in drawEffects(ctx, now: tl.date.timeIntervalSinceReferenceDate) }
            }
            .allowsHitTesting(false)
        }
        .scaleEffect(zoom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("puzzle-board")
    }

    @ViewBuilder private func cellView(_ i: Int, _ size: CGFloat, isTarget: Bool) -> some View {
        let c = board.cells[i]
        let p = center(i, size)
        switch c {
        case .empty:
            Circle().fill(Color(.separator)).frame(width: size * 0.08, height: size * 0.08).position(p).allowsHitTesting(false)
        case .wall:
            WallTile(size: size).position(p).accessibilityLabel("wall")
        case .pink, .ink:
            BlockTile(color: c == .pink ? Theme.accent : .primary, size: size, selected: selected == i, target: isTarget)
                .opacity(flyFrom == i ? 0 : frozen ? 0.3 : 1)
                .keyframeAnimator(initialValue: 0.0, trigger: missTrigger) { content, x in
                    content.offset(x: missCell == i ? CGFloat(x) * size : 0)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.08, duration: 0.05)
                        LinearKeyframe(-0.07, duration: 0.05)
                        LinearKeyframe(0.05, duration: 0.05)
                        LinearKeyframe(-0.03, duration: 0.05)
                        LinearKeyframe(0.0, duration: 0.05)
                    }
                }
                .position(p)
                .onTapGesture { tap(i) }
                .accessibilityElement()
                .accessibilityLabel("\(c == .pink ? "pink" : "black") block, row \(board.row(i) + 1), column \(board.column(i) + 1)")
                .accessibilityValue(selected == i ? "selected" : isTarget ? "can match" : "")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("cell-\(i)")
        }
    }

    private func drawEffects(_ ctx: GraphicsContext, now: Double) {
        if frozen { return }
        let c = Double(cell)
        for r in rings {
            let t = now - r.born
            guard t >= 0, t <= 0.6 else { continue }
            let k = t / 0.6, radius = r.speed * t + 4
            let width: Double = (1 - k) * c * 0.12 + 1
            ctx.stroke(Path(ellipseIn: CGRect(x: r.x - radius, y: r.y - radius, width: radius * 2, height: radius * 2)),
                       with: .color(Theme.accent.opacity((1 - k) * 0.9)), lineWidth: CGFloat(width))
        }
        let gravity = c * 12
        for s in shards {
            let t = now - s.born
            guard t >= 0, t <= s.life else { continue }
            var g = ctx
            g.translateBy(x: s.x + s.vx * t, y: s.y + s.vy * t + 0.5 * gravity * t * t)
            g.rotate(by: .radians(s.spin * t * 3))
            g.fill(Path(CGRect(x: -s.size / 2, y: -s.size / 2, width: s.size, height: s.size)),
                   with: .color(s.color.opacity(1 - t / s.life)))
        }
    }

    // MARK: Play

    private func tap(_ i: Int) {
        guard !busy, !celebrating else { return }
        guard let s = selected else { fb.puzzleSelect(); selected = i; return }
        if s == i { selected = nil }
        else if board.cells[s] == board.cells[i] { fb.puzzleSelect(); selected = i }
        else if board.canMatch(s, i) { play(s, i) }
        // Not reachable from here: the block in hand shakes its head and is put down.
        else { fb.puzzleMiss(); missCell = s; missTrigger += 1; selected = nil }
    }

    private func play(_ from: Int, _ to: Int) {
        busy = true
        selected = nil
        flyFrom = from; flyTo = to; flyDone = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(.easeIn(duration: 0.11)) { flyDone = true }
            try? await Task.sleep(for: .milliseconds(110))
            var next = board
            guard next.match(from, to) else { flyFrom = nil; flyTo = nil; busy = false; return }
            let hit = center(to, cell)
            if next.cleared {
                // Hit-stop: the impact, then the whole frame holds perfectly still.
                fb.puzzleLevelUp(freeze: freezeSeconds)
                frozen = true
                zoom = 1.06
                try? await Task.sleep(for: .milliseconds(Int(freezeSeconds * 1000)))
                clearedCount = board.blocksLeft
                frozen = false
                board = next
                flyFrom = nil; flyTo = nil
                store.puzzleCleared(player.id, level)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.4)) { zoom = 1 }
                burst(at: hit, colors: [Theme.accent, .primary, Theme.accent, .white], count: 90, power: 7)
                let now = clock
                rings += (0..<3).map { Ring(x: hit.x, y: hit.y, born: now + Double($0) * 0.09, speed: Double(cell) * (6 + Double($0) * 2)) }
                shake(Double(cell) * 0.28)
                flash = calm ? 0.35 : 0.92
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(.easeOut(duration: 0.52)) { flash = 0 }
                // Let the explosion read on the board before the card covers it.
                try? await Task.sleep(for: .milliseconds(334))
                withAnimation(.easeOut(duration: 0.2)) { celebrating = true }
            } else {
                fb.puzzleMatch()
                board = next
                flyFrom = nil; flyTo = nil
                burst(at: hit, colors: [Theme.accent, .primary], count: 22, power: 3)
                rings.append(Ring(x: hit.x, y: hit.y, born: clock, speed: Double(cell) * 3))
                shake(Double(cell) * 0.06)
                if next.stuck { try? await Task.sleep(for: .milliseconds(250)); fb.reject() }
            }
            busy = false
        }
    }

    /// Shards flying out from `at`; `power` is roughly how many cells a second the fastest travel.
    private func burst(at: CGPoint, colors: [Color], count: Int, power: Double) {
        let now = clock, c = Double(cell)
        for n in 0..<count {
            let angle = Double.random(in: 0..<(2 * .pi)), speed = Double.random(in: 0.35...1.35) * power * c
            shards.append(Shard(x: at.x, y: at.y, vx: cos(angle) * speed, vy: sin(angle) * speed - power * c / 4,
                                size: c * Double.random(in: 0.07...0.2), born: now, life: Double.random(in: 0.5...1),
                                spin: Double.random(in: -0.7...0.7), color: colors[n % colors.count]))
        }
        // Forget them once they've faded, so the effects layer can stop redrawing.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            let t = clock
            shards.removeAll { t - $0.born > $0.life }
            rings.removeAll { t - $0.born > 0.6 }
        }
    }

    private func shake(_ strength: Double) {
        guard !calm else { return }
        shakeStrength = strength
        shakeTrigger += 1
    }

    private func restart() {
        fb.tap()
        board = store.puzzlePack.board(level)
        selected = nil
    }

    private func nextLevel() {
        fb.unlock()
        shards = []; rings = []; selected = nil
        level = store.puzzleLevel(player.id)
        board = store.puzzlePack.board(level)
        withAnimation(.easeOut(duration: 0.2)) { celebrating = false }
    }
}

/// A block: a rounded tile with a highlight so it reads as solid. Pulses when it's in hand; a
/// dashed ring marks the blocks it can be matched with.
private struct BlockTile: View {
    let color: Color
    let size: CGFloat
    let selected: Bool
    let target: Bool

    var body: some View {
        let side = size * 0.84
        let shape = RoundedRectangle(cornerRadius: size * 0.16)
        ZStack {
            if selected {
                RoundedRectangle(cornerRadius: size * 0.22).fill(Theme.accent.opacity(0.35))
                    .frame(width: side + size * 0.14, height: side + size * 0.14)
            }
            shape.fill(color).frame(width: side, height: side)
            RoundedRectangle(cornerRadius: size * 0.06).fill(Color.white.opacity(0.18))
                .frame(width: side * 0.76, height: side * 0.14)
                .offset(y: -side * 0.33)
            if target {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: size * 0.045, dash: [size * 0.12, size * 0.08]))
                    .frame(width: side + size * 0.08, height: side + size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .phaseAnimator(selected || target ? [0.0, 1.0] : [0.0]) { content, phase in
            content.scaleEffect(selected ? CGFloat(1 + 0.06 * phase) : 1).opacity(target ? 0.75 + 0.25 * phase : 1)
        } animation: { _ in .easeInOut(duration: 0.45) }
        .shadow(color: selected ? Theme.accent.opacity(0.6) : .clear, radius: size * 0.12)
    }
}

private struct WallTile: View {
    let size: CGFloat
    var body: some View {
        let side = size * 0.84
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16)
                .strokeBorder(Color(.tertiaryLabel), style: StrokeStyle(lineWidth: size * 0.05, dash: [size * 0.1, size * 0.07]))
            Path { p in
                p.move(to: CGPoint(x: side * 0.3, y: side * 0.7))
                p.addLine(to: CGPoint(x: side * 0.7, y: side * 0.3))
            }
            .stroke(Color(.tertiaryLabel), lineWidth: size * 0.05)
        }
        .frame(width: side, height: side)
        .frame(width: size, height: size)
    }
}

/// The level-up card: a glitching "LEVEL UP", the new level slamming in, then the way on.
private struct LevelUpCard: View {
    let level: Int
    let cleared: Int
    let calm: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var born = Date()
    @State private var slam = 3.0
    @State private var ready = false
    /// Once the glitch and scanlines have settled the card stops redrawing, so the app goes idle.
    @State private var settled = false

    var body: some View {
        TimelineView(.animation(paused: settled)) { tl in
            let age = tl.date.timeIntervalSince(born)
            let jitter: CGFloat = calm || age > 0.65 ? 0 : CGFloat((Self.noise(Int(age * 25)) - 0.5) * 18 * (1 - age / 0.65))
            // The colour split closes up as the glitch settles, leaving a clean title.
            let split: CGFloat = calm ? 0 : CGFloat(3 * (1 - min(1, age / 0.65)))
            ZStack {
                Color(.systemBackground).opacity(0.82).ignoresSafeArea()
                Canvas { ctx, size in
                    let a: Double = max(0, 1 - age / 1.2) * 0.12
                    guard a > 0 else { return }
                    var y: CGFloat = 0
                    while y < size.height {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 2)), with: .color(Color.primary.opacity(a)))
                        y += 6
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                VStack(spacing: 12) {
                    // The glitch: three copies of the title, split apart and jittering at first.
                    ZStack {
                        title.foregroundStyle(Color.primary.opacity(0.7)).offset(x: -split + jitter)
                        title.foregroundStyle(Theme.accent.opacity(0.85)).offset(x: split - jitter, y: jitter / 3)
                        title.foregroundStyle(Color.primary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("LEVEL UP")
                    Text("LVL \(level)")
                        .font(.system(size: 64, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                        .scaleEffect(slam)
                    Text("\(cleared) blocks cleared").foregroundStyle(.secondary)
                    Spacer().frame(height: 16)
                    if ready {
                        TermButton(label: "NEXT LEVEL", action: onNext)
                        OutlineButton(label: "back to my chores", action: onBack)
                    } else {
                        Color.clear.frame(height: 92)
                    }
                }
                .padding(32)
            }
        }
        .onAppear {
            born = Date()
            if calm { slam = 1 } else { withAnimation(.spring(response: 0.4, dampingFraction: 0.42)) { slam = 1 } }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(750))
                ready = true
                try? await Task.sleep(for: .milliseconds(600))
                settled = true
            }
        }
    }

    private var title: some View {
        Text("LEVEL UP").font(.system(size: 40, weight: .black, design: .monospaced))
    }

    /// Repeatable pseudo-random 0…1 for frame `n`, so the jitter is jagged rather than smooth.
    private static func noise(_ n: Int) -> Double {
        Double((UInt32(truncatingIfNeeded: n) &* 2_654_435_761) >> 16 & 0xFFFF) / 65535
    }
}
