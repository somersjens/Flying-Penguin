//
//  PolarScenery.swift
//  Flying Penguin
//
//  Everything the penguin flies past: sky and clouds, the horizon, the drifting
//  sea ice, the water itself, the launch pad the cannon stands on and the
//  splashes the penguin throws. Every layer reads the playfield's single
//  `worldOffset` and moves at its own parallax, so one conveyor drives the whole
//  scene and nothing can drift out of step with the rings.
//

import SwiftUI

// MARK: - Shared world helpers

enum PolarScene {
    /// All scenery seeds are fixed small integers. Cache their deterministic
    /// wobble once instead of evaluating `sin` throughout every 60 Hz redraw.
    private static let jitterTable: [CGFloat] = (0..<1024).map { calculatedJitter($0) }

    /// Wraps a repeating scenery item into a band that reaches `margin` beyond
    /// both screen edges, so items leave and re-enter fully offscreen instead
    /// of popping into existence at the rim.
    static func scrollX(index: Int,
                        count: Int,
                        width: CGFloat,
                        worldOffset: CGFloat,
                        parallax: CGFloat,
                        margin: CGFloat) -> CGFloat {
        guard count > 0, width > 0 else { return 0 }
        let span = width + margin * 2
        let spacing = span / CGFloat(count)
        let raw = worldOffset * parallax + CGFloat(index) * spacing
        var wrapped = raw.truncatingRemainder(dividingBy: span)
        if wrapped < 0 { wrapped += span }
        return wrapped - margin
    }

    /// Deterministic −1…1 jitter. Every scenery item is drawn from the same
    /// handful of shapes; a seeded wobble is what keeps a row of them from
    /// reading as a repeated stamp.
    static func jitter(_ seed: Int) -> CGFloat {
        if jitterTable.indices.contains(seed) { return jitterTable[seed] }
        return calculatedJitter(seed)
    }

    private static func calculatedJitter(_ seed: Int) -> CGFloat {
        let raw = sin(Double(seed) * 12.9898) * 43758.5453
        return CGFloat((raw - raw.rounded(.down)) * 2 - 1)
    }

    // Shared palette, so the menu backdrop and the playfield stay one world.
    static let skyTop = Color(red: 0.47, green: 0.77, blue: 0.98)
    static let skyMid = Color(red: 0.74, green: 0.91, blue: 1.00)
    static let skyLow = Color(red: 0.94, green: 0.985, blue: 1.00)
    static let iceLight = Color(red: 0.90, green: 0.98, blue: 1.00)
    static let iceMid = Color(red: 0.62, green: 0.88, blue: 0.97)
    static let iceDeep = Color(red: 0.29, green: 0.70, blue: 0.90)
    static let seaShallow = Color(red: 0.28, green: 0.83, blue: 0.95)
    static let seaMid = Color(red: 0.05, green: 0.50, blue: 0.80)
    static let seaDeep = Color(red: 0.01, green: 0.20, blue: 0.55)
    /// Reading colour for copy that sits on the pale menu backdrop.
    static let ink = Color(red: 0.06, green: 0.24, blue: 0.46)
    /// Where the sea crosses `CannonLaunchPad`'s own frame.
    static let padWaterline: CGFloat = 0.40
}

// MARK: - Sky

/// Sky gradient, low polar sun and two parallax bands of clouds.
struct PolarSkyLayer: View {
    let size: CGSize
    let worldOffset: CGFloat

    /// Kept high in the frame and soft, so the answer rings that travel across
    /// the same band always stay the highest-contrast thing on screen.
    private let farBand: [CGFloat] = [0.15, 0.33, 0.21, 0.42]
    private let nearBand: [CGFloat] = [0.10, 0.25, 0.16]

    var body: some View {
        ZStack {
            LinearGradient(colors: [PolarScene.skyTop, PolarScene.skyMid, PolarScene.skyLow],
                           startPoint: .top, endPoint: .bottom)

            Circle()
                .fill(RadialGradient(colors: [.white,
                                              Color(red: 1, green: 0.99, blue: 0.90).opacity(0.55),
                                              Color.white.opacity(0)],
                                     center: .center,
                                     startRadius: size.width * 0.012,
                                     endRadius: size.width * 0.16))
                .frame(width: size.width * 0.32, height: size.width * 0.32)
                .position(x: size.width * 0.79, y: size.height * 0.19)

            ForEach(farBand.indices, id: \.self) { index in
                cloud(index: index,
                      count: farBand.count,
                      y: farBand[index],
                      parallax: 0.05,
                      width: size.width * (0.19 + PolarScene.jitter(index &* 3) * 0.03),
                      opacity: 0.52)
            }

            ForEach(nearBand.indices, id: \.self) { index in
                cloud(index: index,
                      count: nearBand.count,
                      y: nearBand[index],
                      parallax: 0.15,
                      width: size.width * (0.30 + PolarScene.jitter(index &* 7 &+ 2) * 0.045),
                      opacity: 0.80)
            }
        }
        .allowsHitTesting(false)
    }

    private func cloud(index: Int,
                       count: Int,
                       y: CGFloat,
                       parallax: CGFloat,
                       width: CGFloat,
                       opacity: Double) -> some View {
        PolarCloud(seed: index &+ count &* 13)
            .frame(width: width, height: width * 0.45)
            .opacity(opacity)
            .position(x: PolarScene.scrollX(index: index,
                                            count: count,
                                            width: size.width,
                                            worldOffset: worldOffset,
                                            parallax: parallax,
                                            margin: width * 0.75),
                      y: size.height * y)
    }
}

/// A soft cartoon cloud: lobes unioned by a single non-zero fill, with a cooler
/// copy peeking out below for volume. No outline — the sky has to stay quieter
/// than the rings that cross it.
struct PolarCloud: View {
    let seed: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CloudShape(seed: seed)
                    .fill(Color(red: 0.71, green: 0.87, blue: 0.97))
                    .offset(y: proxy.size.height * 0.09)
                CloudShape(seed: seed)
                    .fill(LinearGradient(colors: [.white, Color(red: 0.93, green: 0.98, blue: 1)],
                                         startPoint: .top, endPoint: .bottom))
            }
        }
    }
}

private struct CloudShape: Shape {
    let seed: Int

    private static let lobes: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.30, 0.58, 0.175),
        (0.50, 0.50, 0.225),
        (0.71, 0.60, 0.180),
        (0.845, 0.66, 0.115)
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // The lobes carry the silhouette; the base only closes the flat bottom
        // they all rest on.
        path.addRoundedRect(in: CGRect(x: w * 0.16, y: h * 0.60,
                                       width: w * 0.70, height: h * 0.33),
                            cornerSize: CGSize(width: h * 0.30, height: h * 0.30))
        for (index, lobe) in Self.lobes.enumerated() {
            let wobble = PolarScene.jitter(seed &* 5 &+ index)
            let radius = (lobe.r + wobble * 0.020) * w
            let centre = CGPoint(x: lobe.x * w, y: (lobe.y + wobble * 0.04) * h)
            path.addEllipse(in: CGRect(x: centre.x - radius,
                                       y: centre.y - radius,
                                       width: radius * 2,
                                       height: radius * 2))
        }
        return path
    }
}

// MARK: - Horizon

/// The far shelf: pale ice ridges resting on the waterline. Deliberately low in
/// contrast — the bottom answer ring travels straight through this band.
struct PolarHorizonIce: View {
    let size: CGSize
    let waterline: CGFloat
    let worldOffset: CGFloat

    private let count = 4

    var body: some View {
        ForEach(0..<count, id: \.self) { index in
            let width = size.width * (0.20 + PolarScene.jitter(index &* 11) * 0.05)
            let height = size.height * (0.062 + PolarScene.jitter(index &* 5 &+ 1) * 0.016)
            // Hazy rather than white. Distance is what separates this ridge
            // from the bright blocks drifting in front of it; drawn in the same
            // white the two bands merged into one shelf.
            DriftIceShape(seed: index &* 3 &+ 1, topFraction: 0.94)
                .fill(LinearGradient(colors: [Color(red: 0.87, green: 0.95, blue: 1.0),
                                              PolarScene.iceMid.opacity(0.55)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: height)
                .position(x: PolarScene.scrollX(index: index,
                                                count: count,
                                                width: size.width,
                                                worldOffset: worldOffset,
                                                parallax: 0.10,
                                                margin: width * 0.7),
                          y: waterline - height * 0.47)
                .opacity(0.62)
        }
    }
}

// MARK: - Sea ice

/// Which side of the sea's own surface a band of ice is drawn on.
enum SeaIceDepth {
    /// Behind the water foreground: these blocks sit on the crest, and the
    /// wash sinks their lower half for free.
    case behind
    /// In front of it, and lower in the strip. The visible water is barely a
    /// tenth of the screen, so a block drawn under the wash can only ever sit
    /// on the same line as the horizon — putting the nearest ones over it is
    /// what turns one flat shelf into ice actually floating in the sea.
    case front
}

/// Ice blocks drifting on the sea, at three distances. Everything rides the
/// shared conveyor; the further a band is, the slower it goes.
struct DriftingSeaIce: View {
    let size: CGSize
    let waterline: CGFloat
    let worldOffset: CGFloat
    let isPad: Bool
    let depth: SeaIceDepth
    var exclusionXs: [CGFloat] = []

    private let farCount = 5
    private let midCount = 4
    // Kept low on purpose: this band is drawn over the water and therefore over
    // a diving penguin too. Two blocks read as depth; more of them start
    // covering the moment the player most needs to see.
    private let nearCount = 2

    var body: some View {
        ZStack {
            switch depth {
            case .behind:
                ForEach(0..<farCount, id: \.self) { index in
                    floe(seed: index &* 5,
                         width: size.width * (0.070 + PolarScene.jitter(index &* 17) * 0.016),
                         height: size.height * (0.055 + PolarScene.jitter(index &* 9 &+ 3) * 0.012),
                         index: index,
                         count: farCount,
                         parallax: 0.45,
                         sink: 0,
                         foam: false,
                         opacity: 0.88)
                }
                ForEach(0..<midCount, id: \.self) { index in
                    floe(seed: index &* 7 &+ 2,
                         width: size.width * (0.105 + PolarScene.jitter(index &* 23 &+ 4) * 0.028),
                         height: size.height * (0.082 + PolarScene.jitter(index &* 13 &+ 7) * 0.020),
                         index: index,
                         count: midCount,
                         parallax: 0.78,
                         sink: 0,
                         foam: false,
                         opacity: 1)
                }
            case .front:
                ForEach(0..<nearCount, id: \.self) { index in
                    floe(seed: index &* 11 &+ 5,
                         width: size.width * (0.125 + PolarScene.jitter(index &* 19 &+ 6) * 0.024),
                         height: size.height * (0.082 + PolarScene.jitter(index &* 29 &+ 2) * 0.015),
                         index: index,
                         count: nearCount,
                         parallax: 1.0,
                         sink: size.height * (0.020 + CGFloat(index % 3) * 0.011),
                         foam: true,
                         opacity: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func floe(seed: Int,
                      width: CGFloat,
                      height: CGFloat,
                      index: Int,
                      count: Int,
                      parallax: CGFloat,
                      sink: CGFloat,
                      foam: Bool,
                      opacity: Double) -> some View {
        let x = PolarScene.scrollX(index: index,
                                   count: count,
                                   width: size.width,
                                   worldOffset: worldOffset,
                                   parallax: parallax,
                                   margin: width * 0.8)
        return Group {
            // Foreground ice is selected by placement, not faded at runtime.
            // Since it moves at the same pace as the rings, a rejected slot
            // stays rejected for that ring's complete journey across screen.
            if isClearOfHoops(x: x, floeWidth: width) {
                SeaIceBlock(seed: seed, isPad: isPad, showsFoam: foam)
                    .frame(width: width, height: height)
                    .opacity(opacity)
                    // Lines the block's own waterline up with the sea's — plus
                    // however far in front of it this band floats.
                    .position(x: x,
                              y: waterline + sink
                                  + height * (0.5 - SeaIceBlock.topFraction))
            }
        }
    }

    /// Never create a foreground block in a hoop corridor. Retiring hoop sets
    /// remain exclusions until they are offscreen, so a skipped block cannot
    /// suddenly appear as soon as the player answers.
    private func isClearOfHoops(x: CGFloat, floeWidth: CGFloat) -> Bool {
        switch depth {
        case .behind: return true
        case .front: break
        }
        guard !exclusionXs.isEmpty else { return true }
        let clearRadius = floeWidth * 0.70 + size.width * 0.10
        return exclusionXs.allSatisfy { abs(x - $0) > clearRadius }
    }
}

/// One floating block: a blue underside below the surface, a faceted white slab
/// above it and a snow cap on top.
struct SeaIceBlock: View {
    let seed: Int
    let isPad: Bool
    /// Blocks drawn over the water need to bring their own surface line with
    /// them; the sea's crest passes behind them, not in front.
    var showsFoam = false

    /// Where the sea's surface crosses the block's own frame.
    static let topFraction: CGFloat = 0.62
    private var topFraction: CGFloat { Self.topFraction }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                DriftIceUnderside(seed: seed, topFraction: topFraction)
                    .fill(LinearGradient(colors: [PolarScene.iceDeep.opacity(0.85),
                                                  PolarScene.seaMid.opacity(0.55)],
                                         startPoint: .top, endPoint: .bottom))

                DriftIceShape(seed: seed, topFraction: topFraction)
                    .fill(LinearGradient(colors: [.white,
                                                  PolarScene.iceLight,
                                                  PolarScene.iceMid],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .overlay(
                        DriftIceShape(seed: seed, topFraction: topFraction)
                            .stroke(.white, lineWidth: isPad ? 3 : 2.2)
                    )

                DriftIceFacets(seed: seed, topFraction: topFraction)
                    .stroke(PolarScene.iceDeep.opacity(0.40),
                            style: StrokeStyle(lineWidth: isPad ? 2 : 1.4,
                                               lineCap: .round,
                                               lineJoin: .round))

                // The wet band where the block meets the sea. Without it a
                // white slab on a white horizon has no contact point and the
                // whole waterline reads as one continuous shelf.
                Capsule()
                    .fill(PolarScene.iceDeep.opacity(0.55))
                    .frame(width: w * 0.86, height: max(2, h * 0.055))
                    .position(x: w * 0.5, y: h * topFraction)

                if showsFoam {
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: w * 1.16, height: max(3, h * 0.075))
                        .position(x: w * 0.5, y: h * topFraction + h * 0.02)
                }
            }
        }
        .compositingGroup()
        .shadow(color: PolarScene.seaMid.opacity(0.35), radius: 4, y: 2)
    }
}

/// The part of a floe that stands above the surface: a chunky slab with two
/// peaks, jittered per seed so no two blocks share a silhouette.
struct DriftIceShape: Shape {
    let seed: Int
    let topFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let line = rect.height * topFraction
        let j: (Int) -> CGFloat = { PolarScene.jitter(seed &* 31 &+ $0) }
        var path = Path()
        path.move(to: CGPoint(x: w * 0.02, y: line))
        path.addLine(to: CGPoint(x: w * (0.13 + j(1) * 0.03), y: line * (0.46 + j(2) * 0.10)))
        path.addLine(to: CGPoint(x: w * (0.31 + j(3) * 0.04), y: line * (0.14 + j(4) * 0.08)))
        path.addLine(to: CGPoint(x: w * (0.52 + j(5) * 0.04), y: line * (0.34 + j(6) * 0.10)))
        path.addLine(to: CGPoint(x: w * (0.68 + j(7) * 0.04), y: line * (0.09 + j(8) * 0.07)))
        path.addLine(to: CGPoint(x: w * (0.85 + j(9) * 0.03), y: line * (0.44 + j(10) * 0.10)))
        path.addLine(to: CGPoint(x: w * 0.98, y: line))
        path.closeSubpath()
        return path
    }
}

private struct DriftIceUnderside: Shape {
    let seed: Int
    let topFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let line = h * topFraction
        let j: (Int) -> CGFloat = { PolarScene.jitter(seed &* 19 &+ $0) }
        var path = Path()
        path.move(to: CGPoint(x: w * 0.06, y: line - h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.21, y: h * (0.86 + j(1) * 0.06)))
        path.addLine(to: CGPoint(x: w * 0.43, y: h * (0.99 + j(2) * 0.01)))
        path.addLine(to: CGPoint(x: w * 0.63, y: h * (0.82 + j(3) * 0.08)))
        path.addLine(to: CGPoint(x: w * 0.81, y: h * (0.94 + j(4) * 0.05)))
        path.addLine(to: CGPoint(x: w * 0.94, y: line - h * 0.05))
        path.closeSubpath()
        return path
    }
}

private struct DriftIceFacets: Shape {
    let seed: Int
    let topFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let line = rect.height * topFraction
        let j: (Int) -> CGFloat = { PolarScene.jitter(seed &* 23 &+ $0) }
        var path = Path()
        path.move(to: CGPoint(x: w * (0.31 + j(3) * 0.04), y: line * (0.14 + j(4) * 0.08)))
        path.addLine(to: CGPoint(x: w * 0.38, y: line * 0.88))
        path.move(to: CGPoint(x: w * (0.68 + j(7) * 0.04), y: line * (0.09 + j(8) * 0.07)))
        path.addLine(to: CGPoint(x: w * 0.62, y: line * 0.90))
        return path
    }
}

// MARK: - Water

/// The sea behind everything that floats on it.
struct PolarWaterBackdrop: View {
    let size: CGSize
    let waterline: CGFloat
    let worldOffset: CGFloat
    let isPad: Bool

    var body: some View {
        let amplitude = WaterSurface.amplitude(isPad: isPad)
        let depth = WaterSurface.depth(size: size, waterline: waterline, isPad: isPad)
        ZStack(alignment: .top) {
            WaterBodyShape(phase: worldOffset * 0.55, amplitude: amplitude)
                .fill(LinearGradient(colors: [PolarScene.seaShallow,
                                              PolarScene.seaMid,
                                              PolarScene.seaDeep],
                                     startPoint: .top, endPoint: .bottom))

            // Long, slow swells far out, then quicker chop closer in.
            ForEach(0..<4, id: \.self) { index in
                WaveEdge(phase: worldOffset * (0.30 + CGFloat(index) * 0.12),
                         wavelength: 52 + CGFloat(index) * 9)
                    .stroke(Color.white.opacity(0.26 - Double(index) * 0.042),
                            style: StrokeStyle(lineWidth: isPad ? 4 : 2.5, lineCap: .round))
                    .frame(height: 11)
                    .offset(y: amplitude + CGFloat(index) * (isPad ? 17 : 13))
            }
        }
        .frame(width: size.width, height: depth)
        .position(x: size.width * 0.5,
                  y: waterline - amplitude + depth * 0.5)
    }
}

/// The translucent near half of the sea. Drawn over the penguin and the ice, so
/// anything that dips below the line is visibly under water.
struct PolarWaterForeground: View {
    let size: CGSize
    let waterline: CGFloat
    let worldOffset: CGFloat
    let isPad: Bool

    var body: some View {
        let amplitude = WaterSurface.amplitude(isPad: isPad)
        let depth = WaterSurface.depth(size: size, waterline: waterline, isPad: isPad)
        ZStack(alignment: .top) {
            WaterBodyShape(phase: worldOffset * 0.55, amplitude: amplitude)
                .fill(LinearGradient(colors: [PolarScene.seaShallow.opacity(0.46),
                                              Color(red: 0.02, green: 0.38, blue: 0.70).opacity(0.80)],
                                     startPoint: .top, endPoint: .bottom))

            // The crest itself: one bright, slightly glowing line the eye can
            // lock onto, with a paler echo just under it.
            WaveEdge(phase: worldOffset * 0.55, wavelength: 58)
                .stroke(.white.opacity(0.95),
                        style: StrokeStyle(lineWidth: isPad ? 7 : 5, lineCap: .round))
                .frame(height: amplitude * 2)
                .offset(y: 0)
                .shadow(color: .cyan.opacity(0.55), radius: 4, y: 2)

            WaveEdge(phase: worldOffset * 0.55 + 14, wavelength: 58)
                .stroke(Color(red: 0.45, green: 0.93, blue: 1).opacity(0.70),
                        style: StrokeStyle(lineWidth: isPad ? 3.5 : 2.5, lineCap: .round))
                .frame(height: 13)
                .offset(y: amplitude + (isPad ? 10 : 7))

            SurfaceSparkles(width: size.width,
                            worldOffset: worldOffset,
                            amplitude: amplitude,
                            isPad: isPad)
        }
        .frame(width: size.width, height: depth)
        .position(x: size.width * 0.5,
                  y: waterline - amplitude + depth * 0.5)
        .allowsHitTesting(false)
    }
}

/// Short foam dashes riding the crest. They travel at the full world speed, so
/// they read as the surface itself moving rather than as decoration on it.
private struct SurfaceSparkles: View {
    let width: CGFloat
    let worldOffset: CGFloat
    let amplitude: CGFloat
    let isPad: Bool

    private let count = 12

    var body: some View {
        ForEach(0..<count, id: \.self) { index in
            let jitter = PolarScene.jitter(index &* 29)
            Capsule()
                .fill(.white.opacity(0.42 + Double(abs(jitter)) * 0.28))
                .frame(width: width * (0.016 + abs(jitter) * 0.012),
                       height: isPad ? 2.5 : 1.8)
                .position(x: PolarScene.scrollX(index: index,
                                                count: count,
                                                width: width,
                                                worldOffset: worldOffset,
                                                parallax: 1.0,
                                                margin: width * 0.05),
                          // Hugging the crest reads as foam; further down the
                          // same dashes just looked like litter on the sea.
                          y: amplitude * (1.25 + jitter * 0.35)
                             + CGFloat(index % 3) * (isPad ? 5 : 3.5))
        }
    }
}

/// Both water layers share one surface line, so their wave silhouettes sit
/// exactly on top of each other however the scene is sized.
enum WaterSurface {
    static func amplitude(isPad: Bool) -> CGFloat { isPad ? 11 : 8 }

    static func depth(size: CGSize, waterline: CGFloat, isPad: Bool) -> CGFloat {
        max(1, size.height - waterline + amplitude(isPad: isPad) * 2)
    }
}

/// A travelling wave. `phase` is world distance, so passing the shared
/// `worldOffset` (times a parallax) is all it takes to make the sea scroll.
struct WaveEdge: Shape {
    var phase: CGFloat = 0
    var wavelength: CGFloat = 52

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - wavelength + phase.truncatingRemainder(dividingBy: wavelength)
        path.move(to: CGPoint(x: x, y: rect.midY))
        while x < rect.maxX + wavelength {
            path.addCurve(to: CGPoint(x: x + wavelength, y: rect.midY),
                          control1: CGPoint(x: x + wavelength * 0.25, y: rect.minY),
                          control2: CGPoint(x: x + wavelength * 0.75, y: rect.maxY))
            x += wavelength
        }
        return path
    }
}

/// The filled body of water. Its top edge is the same travelling wave, drawn
/// around `amplitude` so the caller can line the crest up with the waterline.
struct WaterBodyShape: Shape {
    var phase: CGFloat = 0
    var amplitude: CGFloat = 9
    var wavelength: CGFloat = 58

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amp = min(amplitude, rect.height * 0.4)
        let start = rect.minX - wavelength + phase.truncatingRemainder(dividingBy: wavelength)
        var x = start
        path.move(to: CGPoint(x: x, y: amp))
        while x < rect.maxX + wavelength {
            path.addCurve(to: CGPoint(x: x + wavelength, y: amp),
                          control1: CGPoint(x: x + wavelength * 0.25, y: 0),
                          control2: CGPoint(x: x + wavelength * 0.75, y: amp * 2))
            x += wavelength
        }
        path.addLine(to: CGPoint(x: x, y: rect.maxY))
        path.addLine(to: CGPoint(x: start, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Splash

enum WaterSplashDirection: Equatable { case entering, exiting }

/// The original soft water splash, driven by the newer event-based crossing
/// logic so quick successive dives can still overlap reliably.
struct WaterSplash: View {
    let direction: WaterSplashDirection
    let strength: CGFloat
    let reduceMotion: Bool
    @State private var expanded = false

    static func life(direction: WaterSplashDirection,
                     strength: CGFloat,
                     reduceMotion: Bool) -> Double {
        if reduceMotion { return 0.18 }
        return direction == .exiting ? 0.72 : 0.62
    }

    private var clamped: CGFloat { min(1, max(0, strength)) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let energy = 0.76 + clamped * 0.24
            let lift = height * (direction == .exiting ? 0.78 : 0.54) * energy
            ZStack {
                Ellipse()
                    .stroke(.white.opacity(0.92), lineWidth: max(3, width * 0.035))
                    .frame(width: width * 0.68, height: height * 0.24)
                    .scaleEffect(expanded ? 1.35 : 0.28)

                ForEach(0..<9, id: \.self) { index in
                    let spread = (CGFloat(index) - 4) / 4
                    Capsule()
                        .fill(LinearGradient(colors: [.white,
                                                      Color.cyan.opacity(0.82)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: max(5, width * 0.045),
                               height: height * (direction == .exiting ? 0.34 : 0.25) * energy)
                        .rotationEffect(.degrees(Double(spread) * 52))
                        .offset(x: expanded ? spread * width * 0.42 : 0,
                                y: expanded ? -lift * (1 - abs(spread) * 0.38) : height * 0.08)
                }

                ForEach(0..<7, id: \.self) { index in
                    let spread = (CGFloat(index) - 3) / 3
                    Circle()
                        .fill(.white.opacity(0.88))
                        .frame(width: max(4, width * 0.055),
                               height: max(4, width * 0.055))
                        .offset(x: expanded ? spread * width * 0.52 : 0,
                                y: expanded ? -lift * 0.56 - abs(spread) * height * 0.16 : 0)
                }
            }
            .frame(width: width, height: height)
            .position(x: width * 0.5, y: height * 0.55)
            .opacity(expanded ? 0 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.18)
                       : .easeOut(duration: direction == .exiting ? 0.72 : 0.62),
                       value: expanded)
        }
        .onAppear { expanded = true }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Launch pad

/// The ice the cannon is rolled onto. A built launch site rather than a bare
/// floe: a berg with a flat snow deck standing clear of the water, a hazard
/// stripe along its front edge in the cannon's own livery, and an ice face
/// dropping into the sea.
///
/// The frame's own waterline is `PolarScene.padWaterline`; everything above it
/// is the deck the cannon stands on and everything below is the ice cliff, so
/// the caller only has to line those two fractions up with the sea.
struct CannonLaunchPad: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                LaunchPadUnderside()
                    .fill(LinearGradient(colors: [PolarScene.iceDeep.opacity(0.92),
                                                  PolarScene.seaMid.opacity(0.62)],
                                         startPoint: .top, endPoint: .bottom))

                // The gradient's stops are pinned to the waterline, so the ice
                // goes blue exactly where the sea starts. A single top-to-bottom
                // wash left the whole thing white, which is what made it read
                // as the hull of a boat rather than as ice.
                LaunchPadDeck()
                    .fill(LinearGradient(stops: [
                        .init(color: .white, location: 0.10),
                        .init(color: PolarScene.iceLight, location: 0.34),
                        .init(color: PolarScene.iceMid, location: PolarScene.padWaterline),
                        .init(color: PolarScene.iceDeep.opacity(0.95), location: 0.56),
                        .init(color: PolarScene.seaMid.opacity(0.85), location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .overlay(LaunchPadDeck().stroke(.white, lineWidth: max(2, w * 0.007)))

                // A shaded plane down the right of the berg. Ice reads as ice
                // because it has facets catching the light differently.
                LaunchPadShadedFace()
                    .fill(PolarScene.iceMid.opacity(0.45))

                LaunchPadFacets()
                    .stroke(PolarScene.iceDeep.opacity(0.32),
                            style: StrokeStyle(lineWidth: max(1.5, w * 0.005),
                                               lineCap: .round,
                                               lineJoin: .round))

                // The short launch strip the cannon's wheels stand on, in its
                // own livery. A stripe running the full width read as the hull
                // of a boat instead.
                LaunchPadStripes(width: w, height: h)

                // Where the sea meets the ice.
                Capsule()
                    .fill(.white.opacity(0.88))
                    .frame(width: w * 0.80, height: max(3, h * 0.05))
                    .position(x: w * 0.5, y: h * PolarScene.padWaterline)

                // Loose chunks calving off the near edge.
                ForEach(0..<2, id: \.self) { index in
                    let side: CGFloat = index == 0 ? -1 : 1
                    SeaIceBlock(seed: index &* 13 &+ 3, isPad: false, showsFoam: true)
                        .frame(width: w * 0.19, height: h * 0.46)
                        .position(x: w * (0.5 + side * 0.58),
                                  y: h * (PolarScene.padWaterline
                                          + 0.46 * (0.5 - SeaIceBlock.topFraction)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// A berg, not a jetty: an angular crest with a cut-flat middle for the cannon
/// to stand on, over an ice face that tapers inward as it drops into the sea.
private struct LaunchPadDeck: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.02, y: h * 0.40))
        path.addLine(to: CGPoint(x: w * 0.11, y: h * 0.27))
        path.addLine(to: CGPoint(x: w * 0.17, y: h * 0.11))
        path.addLine(to: CGPoint(x: w * 0.245, y: h * 0.215))
        // The levelled strip the wheels rest on.
        path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.155))
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.165))
        path.addLine(to: CGPoint(x: w * 0.775, y: h * 0.075))
        path.addLine(to: CGPoint(x: w * 0.855, y: h * 0.235))
        path.addLine(to: CGPoint(x: w * 0.915, y: h * 0.165))
        path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.40))
        // A ragged, tapering keel. A straight bottom edge under a straight top
        // edge is a hull, however the ice above it is shaped.
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.60))
        path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.64))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.80))
        path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.66))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.76))
        path.closeSubpath()
        return path
    }
}

/// The right-hand planes of the berg, turned away from the low polar sun.
private struct LaunchPadShadedFace: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.775, y: h * 0.075))
        path.addLine(to: CGPoint(x: w * 0.855, y: h * 0.235))
        path.addLine(to: CGPoint(x: w * 0.915, y: h * 0.165))
        path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.40))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.60))
        path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.62))
        path.closeSubpath()

        path.move(to: CGPoint(x: w * 0.17, y: h * 0.11))
        path.addLine(to: CGPoint(x: w * 0.245, y: h * 0.215))
        path.addLine(to: CGPoint(x: w * 0.225, y: h * 0.68))
        path.addLine(to: CGPoint(x: w * 0.175, y: h * 0.66))
        path.closeSubpath()
        return path
    }
}

private struct LaunchPadUnderside: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.17, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.27, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.88))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 1.04))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.86))
        path.addLine(to: CGPoint(x: w * 0.79, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.58))
        path.closeSubpath()
        return path
    }
}

/// The couple of cracks that keep the ice face from reading as a painted board.
private struct LaunchPadFacets: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.245, y: h * 0.215))
        path.addLine(to: CGPoint(x: w * 0.225, y: h * 0.68))
        path.move(to: CGPoint(x: w * 0.855, y: h * 0.235))
        path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.62))
        path.move(to: CGPoint(x: w * 0.55, y: h * 0.165))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.70))
        return path
    }
}

private struct LaunchPadStripes: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: 2)
                          ? Color(red: 0.88, green: 0.20, blue: 0.20)
                          : Color.white)
            }
        }
        .frame(width: width * 0.40, height: max(3, height * 0.05))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1.2))
        .position(x: width * 0.40, y: height * 0.305)
        .opacity(0.95)
    }
}
