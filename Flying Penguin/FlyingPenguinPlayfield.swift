import SwiftUI
import Combine

/// The Flying Penguin interaction. Session rules remain in `MemoryGame`; this
/// view only turns a vertical flight path (or a dive) into one option id.
struct FlyingPenguinPlayfield: View {
    let rounds: [GameRound]
    let maximumRounds: Int
    let character: AnimalCharacter
    let isPad: Bool
    let isLive: Bool
    let isRunning: Bool
    let playsFishEntrance: Bool
    let preparesLevelCompletion: Bool
    let playsLevelCompletion: Bool
    let reduceMotion: Bool
    let topReserve: CGFloat
    let bottomReserve: CGFloat
    var tutorialMessage: String? = nil
    var tutorialSymbol: String? = nil
    var tutorialPointer: TutorialPointer? = nil
    let onHit: (UUID, Bool, Bool) -> Bool
    let onImpact: () -> Void
    let onSwallow: (Bool) -> Void
    let onDive: () -> Void
    let onFishEntranceComplete: () -> Void
    let onLevelCompletionFinished: () -> Void

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    @State private var sceneSize: CGSize = .zero
    @State private var penguinY: CGFloat = 0
    @State private var targetPenguinY: CGFloat = 0
    @State private var dragStartY: CGFloat?
    @State private var penguinX: CGFloat = 0
    @State private var hoopX: CGFloat = 0
    @State private var shownOptions: [AnswerOption] = []
    @State private var shownPrompt = ""
    @State private var previewOptions: [AnswerOption] = []
    @State private var previewPrompt = ""
    @State private var previewRoundID: UUID?
    @State private var previewHasNoCorrectAnswer = false
    @State private var retiringSets: [RetiringHoopSet] = []
    @State private var activeRoundID: UUID?
    @State private var noCorrectAnswer = false
    @State private var resolved = false
    /// A wrong passage reveals the solution in the moving sum and briefly
    /// repeats it at the lower-left edge while flight continues uninterrupted.
    @State private var answerEcho: SolvedAnswerEcho?
    @State private var emphasizesCorrectAnswer = false
    @State private var diveArmed = false
    @State private var divePhase = 0
    @State private var committedLaneIndex: Int?
    @State private var speedRunActive = false
    @State private var speedBonusEligible = false
    @State private var goldenOptionID: UUID?
    @State private var worldOffset: CGFloat = 0
    @State private var entranceStage = 0
    @State private var completionActive = false
    @State private var completionProgress: CGFloat = 0
    @State private var completionStart = CGPoint.zero
    /// A small continuation of the last passage during its feedback beat. It
    /// hands the penguin to the loop with forward momentum instead of a pause.
    @State private var completionLeadX: CGFloat = 0
    /// Invalidates a delayed finale callback when a fresh run starts.
    @State private var completionSequence = 0
    @State private var lastTick: Date?
    @State private var launchGlideSpeed: CGFloat = 0
    @State private var launchSpeedHandoffActive = false
    @State private var startMarkerActive = false
    /// The world position the cannon was fired from. Everything standing on the
    /// water during the entrance — platform and start marker — is placed
    /// relative to it, so the launch scenery travels on the same conveyor as
    /// the rings instead of on a camera animation of its own.
    @State private var launchWorldOrigin: CGFloat = 0
    @State private var launchPlatformActive = false
    /// Splashes are fired as events rather than toggled as flags. A boolean
    /// that has to be cleared before it can be set again is exactly what made
    /// a dive occasionally arrive without one; an appended event cannot be
    /// swallowed by whatever the dive state does next.
    @State private var splashes: [SplashEvent] = []
    /// Latches at the surface so one crossing produces one splash, whether the
    /// penguin swam down to it or was placed under it by a resolved round.
    @State private var surfaceSubmerged = false
    @State private var previousPenguinY: CGFloat = 0
    /// The height the current dive started from, which is what the entry
    /// splash is sized by.
    @State private var diveStartY: CGFloat = 0
    @State private var flightClock: Double = 0

    private var penguinSize: CGFloat { sceneSize.height * (isPad ? 0.27 : 0.235) }
    /// The rings leave a dedicated header band for the moving sum.
    /// Three touching hoops fill the complete answer column. Their shared size
    /// is derived from the available height, so there is no traversable gap.
    private var hoopSize: CGFloat {
        let questionBottom = sceneSize.height * 0.141
        let answerBottom = waterline - sceneSize.height * 0.012
        return max(1, (answerBottom - questionBottom) / 3)
    }
    private var waterline: CGFloat { sceneSize.height * 0.90 }
    private var normalPenguinX: CGFloat { sceneSize.width * 0.25 }
    private var flightMinY: CGFloat {
        // Leave a little headroom above the top answer centre without letting
        // the character collide with the moving question badge.
        max(questionY + penguinSize * 0.46,
            (lanes.first ?? sceneSize.height * 0.27) - hoopSize * 0.22)
    }
    private var flightMaxY: CGFloat { lanes.last ?? sceneSize.height * 0.76 }
    private var diveY: CGFloat { waterline + penguinSize * 0.68 }

    private var lanes: [CGFloat] {
        let first = sceneSize.height * 0.141 + hoopSize * 0.5
        return [first, first + hoopSize, first + hoopSize * 2]
    }

    private var questionY: CGFloat { sceneSize.height * 0.090 }
    private var ringSpawnX: CGFloat {
        // Fully beyond the trailing edge, so a set always slides into frame
        // rather than appearing with its rim already inside it. The first set
        // is put on the conveyor at the moment of the shot and covers most of
        // this distance during the launch itself.
        sceneSize.width + hoopSize * 0.55
    }
    private var ringSetSpacing: CGFloat {
        sceneSize.width - normalPenguinX + hoopSize * 0.20
    }
    private var previewX: CGFloat {
        hoopX + ringSetSpacing
    }
    private var cruiseSpeed: CGFloat {
        // Removing the former 1.5x multiplier gives exactly 50% more time
        // between sets without pushing the already-visible preview offscreen.
        max(80, (sceneSize.width + hoopSize - normalPenguinX) / 5)
    }
    /// The lane assist is time based as well as size based. Turbo attempts
    /// therefore get more physical runway instead of cutting the correction
    /// window in half when the conveyor doubles its speed.
    private var approachSpeed: CGFloat {
        cruiseSpeed * (speedRunActive && !resolved ? 2 : 1)
    }
    private var laneAssistDistance: CGFloat {
        max(hoopSize * 0.42, approachSpeed * 0.36)
    }
    private var laneCommitDistance: CGFloat {
        max(hoopSize * 0.14, approachSpeed * 0.13)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                polarBackdrop

                movingWorld

                // The deadline buoy belongs to a set. Before the start marker
                // hands the first one over there is nothing to be early for.
                if entranceStage >= 3 && !completionActive && !shownOptions.isEmpty {
                    TurboTimingBuoy(isAvailable: timingMarkerX(for: hoopX) > penguinX)
                        .frame(width: penguinSize * 0.25, height: penguinSize * 0.31)
                        .position(x: timingMarkerX(for: hoopX),
                                  y: waterline - penguinSize * 0.05)
                    if !previewOptions.isEmpty {
                        TurboTimingBuoy(isAvailable: true)
                            .frame(width: penguinSize * 0.25, height: penguinSize * 0.31)
                            .position(x: timingMarkerX(for: previewX),
                                      y: waterline - penguinSize * 0.05)
                    }
                }

                if launchPlatformActive {
                    cannonLaunch
                }

                if startMarkerActive {
                    FloatingStartMarker(size: penguinSize * 0.58,
                                        reduceMotion: reduceMotion)
                        .position(x: startMarkerX,
                                  y: waterline - penguinSize * 0.12)
                        .allowsHitTesting(false)
                }

                ForEach(retiringSets) { set in
                    MovingQuestionBadge(prompt: set.prompt,
                                        character: character,
                                        isPad: isPad)
                        .position(x: set.x, y: questionY)
                    ForEach(Array(set.options.enumerated()), id: \.element.id) { index, option in
                        AnswerHoop(text: option.text,
                                   tint: character.color,
                                   size: hoopSize,
                                   feedback: set.feedback(for: option.id))
                            .position(x: set.x, y: lanes[index])
                    }
                }

                if !previewOptions.isEmpty && entranceStage >= 3 && !completionActive {
                    MovingQuestionBadge(prompt: previewPrompt,
                                        character: character,
                                        isPad: isPad)
                        .position(x: previewX, y: questionY)
                    ForEach(Array(previewOptions.enumerated()), id: \.element.id) { index, option in
                        AnswerHoop(text: option.text,
                                   tint: character.color,
                                   size: hoopSize,
                                   feedback: .none)
                            .position(x: previewX, y: lanes[index])
                    }
                }

                if !shownOptions.isEmpty && entranceStage >= 3 && !completionActive {
                    MovingQuestionBadge(prompt: shownPrompt,
                                        character: character,
                                        isPad: isPad)
                        .position(x: hoopX, y: questionY)
                    ForEach(Array(shownOptions.enumerated()), id: \.element.id) { index, option in
                        AnswerHoop(text: option.text,
                                   tint: character.color,
                                   size: hoopSize,
                                   feedback: feedback(for: option.id))
                            .position(x: hoopX, y: lanes[index])
                    }
                }

                if speedRunActive && !resolved {
                    GoldenSpeedTrail(size: penguinSize, phase: flightClock)
                        .position(x: penguinX - penguinSize * 0.58, y: penguinY)
                        .transition(.opacity)
                }

                RiggedPenguin(size: penguinSize,
                              pose: penguinPose,
                              flightMotion: penguinFlightMotion,
                              reduceMotion: reduceMotion,
                              flightClock: flightClock)
                    .modifier(CompletionFlightEffect(
                        progress: completionActive ? completionProgress : 0,
                        sceneSize: sceneSize,
                        start: completionStart,
                        penguinSize: penguinSize,
                        reduceMotion: reduceMotion
                    ))
                    // The reveal belongs to the muzzle, not to the flight. It
                    // used to inherit the launch curve's own 0.72s, which left
                    // a half-transparent penguin hanging over the whole arc.
                    .opacity(entranceStage < 3 ? 0 : 1)
                    .animation(.easeOut(duration: reduceMotion ? 0.03 : 0.16),
                               value: entranceStage >= 3)
                    .position(x: completionActive ? completionStart.x : displayedPenguinX + completionLeadX,
                              y: completionActive ? completionStart.y : displayedPenguinY)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 4)
                    .allowsHitTesting(false)

                // A second, near-side half of every hoop sits above the
                // penguin. The complete hoop below plus this arc above makes
                // the character visibly pass through the opening.
                hoopForegrounds

                if launchPlatformActive {
                    cannonForeground
                }

                waterForeground

                if launchPlatformActive {
                    cannonPlatform
                }

                ForEach(splashes) { splash in
                    WaterSplash(direction: splash.direction,
                                strength: splash.strength,
                                reduceMotion: reduceMotion)
                        .frame(width: penguinSize * (1.15 + splash.strength * 0.80),
                               height: penguinSize * (0.78 + splash.strength * 0.62))
                        .position(x: splash.x, y: waterline)
                        .allowsHitTesting(false)
                }

                if let answerEcho, entranceStage >= 5, !completionActive {
                    SolvedAnswerEchoView(prompt: answerEcho.prompt,
                                         character: character,
                                         isPad: isPad)
                        .frame(maxWidth: proxy.size.width * 0.46, alignment: .leading)
                        .position(x: proxy.size.width * 0.25,
                                  y: proxy.size.height - bottomReserve - (isPad ? 88 : 68))
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                if let tutorialMessage, entranceStage >= 5 {
                    Text(tutorialMessage)
                        .font(.system(size: isPad ? 20 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(character.deepColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.92), in: Capsule())
                        .position(x: proxy.size.width * 0.52, y: proxy.size.height - bottomReserve - 28)
                }
            }
            .contentShape(Rectangle())
            .gesture(flightGesture)
            .simultaneousGesture(ringTapGesture)
            .onAppear {
                updateLayout(proxy.size)
                if playsFishEntrance { beginEntrance() }
                else { resolved = true }
            }
            .onChange(of: proxy.size) { _, value in updateLayout(value) }
        }
        .ignoresSafeArea()
        .onReceive(timer, perform: tick)
        .onChange(of: rounds.first?.id) { _, _ in configureRound(force: true) }
        .onChange(of: isLive) { _, live in
            if live && resolved { configureRound(force: true) }
        }
        .onChange(of: playsFishEntrance) { _, value in if value { beginEntrance() } }
        .onChange(of: preparesLevelCompletion) { _, value in
            guard value, !completionActive else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.05 : 0.30)) {
                completionLeadX = sceneSize.width * 0.045
            }
        }
        .onChange(of: playsLevelCompletion) { _, value in if value { beginCompletion() } }
    }

    private var polarBackdrop: some View {
        ZStack {
            PolarSkyLayer(size: sceneSize, worldOffset: worldOffset)
            PolarHorizonIce(size: sceneSize,
                            waterline: waterline,
                            worldOffset: worldOffset)
            PolarWaterBackdrop(size: sceneSize,
                               waterline: waterline,
                               worldOffset: worldOffset,
                               isPad: isPad)
        }
        .clipped()
        .allowsHitTesting(false)
    }

    /// Everything that floats between the sea's two halves. Drawn before the
    /// rings and under the water foreground, so the wash sinks the lower half
    /// of every block for free.
    private var movingWorld: some View {
        DriftingSeaIce(size: sceneSize,
                       waterline: waterline,
                       worldOffset: worldOffset,
                       isPad: isPad,
                       depth: .behind)
    }

    private var waterForeground: some View {
        ZStack {
            PolarWaterForeground(size: sceneSize,
                                 waterline: waterline,
                                 worldOffset: worldOffset,
                                 isPad: isPad)
            DriftingSeaIce(size: sceneSize,
                           waterline: waterline,
                           worldOffset: worldOffset,
                           isPad: isPad,
                           depth: .front,
                           // A foreground floe directly below a ring stack
                           // reads as a solid obstacle. Keep that gameplay
                           // corridor visually open, including while an old
                           // set is drifting out after an answer.
                           exclusionXs: [hoopX] + retiringSets.map(\.x))
        }
    }

    /// The cannon stands on the pad's deck, so both are placed from the same
    /// number: raise or lower one and the other follows.
    private var cannonCentreY: CGFloat { sceneSize.height * 0.735 }

    private var cannonLaunch: some View {
        CannonLaunchScene(stage: entranceStage,
                          reduceMotion: reduceMotion,
                          layer: .base)
            .frame(width: sceneSize.width * 0.269,
                   height: sceneSize.width * 0.179)
            .position(x: launchPlatformX, y: cannonCentreY)
            .allowsHitTesting(false)
    }

    private var cannonForeground: some View {
        CannonLaunchScene(stage: entranceStage,
                          reduceMotion: reduceMotion,
                          layer: .barrelForeground)
            .frame(width: sceneSize.width * 0.269,
                   height: sceneSize.width * 0.179)
            .position(x: launchPlatformX, y: cannonCentreY)
            .allowsHitTesting(false)
    }

    /// Drawn after the sea, not with the cannon. The launch site is the nearest
    /// thing in the world; behind the water it was hidden by whichever floe
    /// happened to be drifting past — and since both travel at the same speed,
    /// that floe stayed in the way for the whole entrance.
    private var cannonPlatform: some View {
        let height = sceneSize.height * 0.17
        return CannonLaunchPad()
            .frame(width: sceneSize.width * 0.25, height: height)
            .position(x: launchPlatformX,
                      y: waterline + height * (0.5 - PolarScene.padWaterline))
            .allowsHitTesting(false)
    }

    /// How far the launch site has travelled since the shot. It is pure world
    /// movement: the platform stands still while the fuse burns, leaves frame at
    /// the muzzle speed, and keeps drifting at exactly the speed of the water
    /// and the rings once the player has control. No stage ever moves it by
    /// itself, so the hand-over cannot produce a jump or a second pace.
    private var launchCameraOffset: CGFloat { worldOffset - launchWorldOrigin }

    private var launchPlatformX: CGFloat {
        sceneSize.width * 0.145 + launchCameraOffset
    }

    private var startMarkerX: CGFloat {
        sceneSize.width * 0.58 + launchCameraOffset
    }

    private var flightGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let canSurface = (1...4).contains(divePhase)
                guard isRunning, entranceStage >= 5, !completionActive,
                      (isLive || canSurface), (!resolved || canSurface),
                      committedLaneIndex == nil else { return }
                // The choice remains live throughout the assist zone. Only the
                // short commit zone at the hoop itself stops accepting a new
                // lane, so a late drag can still redirect an in-flight penguin.
                if dragStartY == nil { dragStartY = targetPenguinY == 0 ? penguinY : targetPenguinY }
                // Movement is relative to where the penguin was when the drag
                // began. Touching elsewhere on screen therefore never makes it
                // jump to the finger.
                let requested = (dragStartY ?? penguinY) + value.translation.height
                if requested >= waterline {
                    armDive()
                } else {
                    diveArmed = false
                    if canSurface {
                        // Once recovery has started, keep its smooth arm turn
                        // intact while still accepting a new target height.
                        if divePhase != 4 { divePhase = 3 }
                    } else {
                        divePhase = 0
                    }
                    targetPenguinY = min(max(requested, flightMinY), flightMaxY)
                }
            }
            .onEnded { _ in dragStartY = nil }
    }

    private var ringTapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in handleRingTap(at: value.location) }
    }

    private func handleRingTap(at location: CGPoint) {
        guard isLive, isRunning, entranceStage >= 5, !resolved,
              committedLaneIndex == nil,
              location.x >= hoopX - hoopSize * 0.72 else { return }

        dragStartY = nil
        let isEarly = timingMarkerX(for: hoopX) > penguinX
        speedRunActive = true
        speedBonusEligible = isEarly

        if location.y > lanes[2] + hoopSize * 0.46 {
            armDive()
            return
        }

        let lane = lanes.enumerated().min {
            abs($0.element - location.y) < abs($1.element - location.y)
        }?.offset ?? 1
        if divePhase == 1 || divePhase == 2 || divePhase == 3 {
            divePhase = 3
        } else if divePhase != 4 {
            divePhase = 0
        }
        diveArmed = false
        targetPenguinY = lanes[lane]
    }

    private func timingMarkerX(for ringX: CGFloat) -> CGFloat {
        ringX - cruiseSpeed * 1.55
    }

    private var displayedPenguinX: CGFloat {
        switch entranceStage {
        case 0, 1: return sceneSize.width * 0.22
        case 2: return sceneSize.width * 0.245
        case 3: return normalPenguinX
        case 4: return normalPenguinX
        default: return penguinX
        }
    }

    private var displayedPenguinY: CGFloat {
        switch entranceStage {
        // The muzzle's own height, so the penguin leaves the barrel rather than
        // appearing beside it. It follows `cannonCentreY`.
        case 0, 1, 2: return cannonCentreY - sceneSize.width * 0.179 * 0.22
        case 3: return lanes[1]
        case 4: return lanes[1]
        default: return penguinY
        }
    }

    private var penguinPose: PenguinPose {
        if completionActive { return .flying }
        if divePhase == 1 { return .diving }
        if divePhase == 2 { return .underwater }
        if divePhase == 3 { return .resurfacing }
        if divePhase == 4 { return .recovering }
        switch entranceStage {
        case 0: return .loaded
        case 1: return .compressed
        case 2, 3: return .launching
        default:
            if abs(hoopX - penguinX) < hoopSize * 0.62 { return .threading }
            return .flying
        }
    }

    @ViewBuilder private var hoopForegrounds: some View {
        ForEach(retiringSets) { set in
            if abs(set.x - penguinX) < hoopSize * 1.15 {
                ForEach(Array(set.options.enumerated()), id: \.element.id) { index, option in
                    AnswerHoopForeground(tint: character.color,
                                         size: hoopSize,
                                         feedback: set.feedback(for: option.id))
                        .position(x: set.x, y: lanes[index])
                        .opacity(hoopOcclusionOpacity(at: set.x))
                }
            }
        }
        if !shownOptions.isEmpty && entranceStage >= 3 && !completionActive,
           abs(hoopX - penguinX) < hoopSize * 1.15 {
            ForEach(Array(shownOptions.enumerated()), id: \.element.id) { index, option in
                AnswerHoopForeground(tint: character.color,
                                     size: hoopSize,
                                     feedback: feedback(for: option.id))
                    .position(x: hoopX, y: lanes[index])
                    .opacity(hoopOcclusionOpacity(at: hoopX))
            }
        }
    }

    private func hoopOcclusionOpacity(at x: CGFloat) -> Double {
        let fadeStart = hoopSize * 1.15
        let fadeEnd = hoopSize * 0.82
        let distance = abs(x - penguinX)
        return Double(min(1, max(0, (fadeStart - distance) / (fadeStart - fadeEnd))))
    }

    private var penguinFlightMotion: PenguinFlightMotion {
        if completionActive { return .level }
        guard entranceStage >= 5, divePhase == 0 else { return .level }
        let delta = targetPenguinY - penguinY
        if delta < -2 { return .rising }
        if delta > 2 { return .falling }
        return .level
    }

    private func updateLayout(_ size: CGSize) {
        sceneSize = size
        penguinX = normalPenguinX
        if penguinY == 0 {
            penguinY = lanes[1]
            targetPenguinY = penguinY
            previousPenguinY = penguinY
            diveStartY = penguinY
        }
        if hoopX == 0 { hoopX = ringSpawnX }
    }

    private func beginEntrance() {
        completionSequence &+= 1
        completionActive = false
        completionProgress = 0
        completionStart = .zero
        completionLeadX = 0
        entranceStage = 0
        resolved = true
        shownOptions = []
        shownPrompt = ""
        previewOptions = []
        previewPrompt = ""
        previewRoundID = nil
        retiringSets = []
        activeRoundID = nil
        answerEcho = nil
        emphasizesCorrectAnswer = false
        hoopX = ringSpawnX
        penguinX = normalPenguinX
        penguinY = lanes[1]
        targetPenguinY = penguinY
        dragStartY = nil
        noCorrectAnswer = false
        diveArmed = false
        divePhase = 0
        committedLaneIndex = nil
        splashes = []
        surfaceSubmerged = false
        previousPenguinY = penguinY
        diveStartY = penguinY
        lastTick = nil
        flightClock = 0
        speedRunActive = false
        speedBonusEligible = false
        goldenOptionID = nil
        launchSpeedHandoffActive = false
        launchGlideSpeed = 0
        launchWorldOrigin = worldOffset
        launchPlatformActive = true
        startMarkerActive = true
        let fuseDuration = reduceMotion ? 0.12 : 1.45
        let squeezeDuration = reduceMotion ? 0.06 : 0.24
        let flightDuration = reduceMotion ? 0.10 : 0.72
        DispatchQueue.main.asyncAfter(deadline: .now() + fuseDuration * 0.72) {
            withAnimation(.spring(response: squeezeDuration, dampingFraction: 0.58)) { entranceStage = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fuseDuration) {
            withAnimation(.easeOut(duration: reduceMotion ? 0.03 : 0.10)) { entranceStage = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fuseDuration + 0.10) {
            // The shot starts the world. From this frame one deceleration curve
            // carries the scenery, the launch platform and the first ring set,
            // straight through the moment the player takes over.
            launchGlideSpeed = sceneSize.width * 1.25
            launchSpeedHandoffActive = true
            withAnimation(.timingCurve(0.12, 0.72, 0.78, 0.88,
                                       duration: flightDuration)) { entranceStage = 3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fuseDuration + 0.10 + flightDuration) {
            withAnimation(.easeOut(duration: reduceMotion ? 0.03 : 0.08)) { entranceStage = 5 }
            // A no-op once the start marker has handed the first set over. It
            // only does the work itself when the launch was too short for the
            // marker to be passed, as with reduced motion.
            configureRound(force: false)
            resolved = false
            if reduceMotion {
                // Nothing drifts out of frame on its own here, so the launch
                // site leaves with the entrance it belongs to.
                launchPlatformActive = false
                startMarkerActive = false
            }
            onFishEntranceComplete()
        }
    }

    private func configureRound(force: Bool) {
        // From the shot onwards, so the first set can already be travelling
        // while the penguin is still leaving the barrel.
        guard entranceStage >= 3, let round = rounds.first, sceneSize.width > 0 else { return }
        guard force || activeRoundID != round.id else { return }
        let promotesPreview = previewRoundID == round.id
        let promotedX = previewX
        if !shownOptions.isEmpty, hoopX > -hoopSize * 0.65 {
            retiringSets.append(RetiringHoopSet(options: shownOptions,
                                                prompt: shownPrompt,
                                                x: hoopX,
                                                goldenOptionID: goldenOptionID))
            if retiringSets.count > 1 { retiringSets.removeFirst(retiringSets.count - 1) }
        }
        activeRoundID = round.id
        shownPrompt = round.question.prompt
        if promotesPreview {
            shownOptions = previewOptions
            noCorrectAnswer = previewHasNoCorrectAnswer
            hoopX = promotedX
        } else {
            let presentation = presentation(for: round)
            shownOptions = presentation.options
            noCorrectAnswer = presentation.hasNoCorrectAnswer
            hoopX = ringSpawnX
        }
        configurePreview()
        penguinX = normalPenguinX
        resolved = false
        diveArmed = false
        committedLaneIndex = nil
        speedRunActive = false
        speedBonusEligible = false
        goldenOptionID = nil
        emphasizesCorrectAnswer = false
        // Keep the exact flight height between sets. Only a completed dive
        // changes it as part of its resurfacing sequence.
    }

    private func configurePreview() {
        guard rounds.count > 1 else {
            previewRoundID = nil
            previewPrompt = ""
            previewOptions = []
            previewHasNoCorrectAnswer = false
            return
        }
        let round = rounds[1]
        let presentation = presentation(for: round)
        previewRoundID = round.id
        previewPrompt = round.question.prompt
        previewOptions = presentation.options
        previewHasNoCorrectAnswer = presentation.hasNoCorrectAnswer
    }

    private func presentation(for round: GameRound) -> (options: [AnswerOption], hasNoCorrectAnswer: Bool) {
        // Stable per generated round, but not tied to a repeating question
        // interval. Independent buckets naturally allow two dive rounds in a
        // row while keeping the overall chance close to one in four.
        let seed = round.id.uuidString.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        let hasNoCorrectAnswer = seed.isMultiple(of: 4)
        let wrong = round.options.filter { !$0.isCorrect }
        if hasNoCorrectAnswer {
            return (Array(wrong.prefix(3)), true)
        }
        guard let correct = round.correctOption else { return (Array(wrong.prefix(3)), false) }
        let choices = [correct] + Array(wrong.prefix(2))
        let offset = round.number % choices.count
        return (Array(choices[offset...] + choices[..<offset]), false)
    }

    private func tick(_ now: Date) {
        defer { lastTick = now }
        guard let lastTick else { return }
        guard isRunning else { return }
        let dt = min(0.05, now.timeIntervalSince(lastTick))
        if completionActive {
            // The world has stopped, but the wings keep beating throughout the
            // looping exit so the penguin never turns into a rigid cut-out.
            if !reduceMotion { flightClock += dt }
            // The solved hoops belong to the passage that just happened. Let
            // them finish travelling off-screen instead of deleting or
            // freezing them when the finale takes over the penguin.
            let hoopStep = cruiseSpeed * CGFloat(dt)
            for index in retiringSets.indices { retiringSets[index].x -= hoopStep }
            retiringSets.removeAll { $0.x < -hoopSize * 0.65 }
            return
        }

        // Nothing moves while the fuse burns. From the shot on, one conveyor
        // carries everything that stands in the world — scenery, launch site,
        // start marker and rings — at one shared speed.
        guard entranceStage >= 3 else { return }
        advanceWorld(dt: CGFloat(dt))

        guard entranceStage >= 5 else { return }
        if !reduceMotion { flightClock += dt }

        // One critically damped movement path owns vertical control. It reacts
        // quickly to the drag target without stacking SwiftUI spring animations
        // or producing velocity after the finger stops.
        if targetPenguinY != 0 {
            let delta = targetPenguinY - penguinY
            // The wings turn quickly into the streamlined pose, so the actual
            // dive can remain responsive instead of slowing gameplay down.
            let response: CGFloat = divePhase == 1 ? 11 : 13
            let desiredStep = delta * (1 - exp(-response * CGFloat(dt)))
            let maxSpeed = sceneSize.height * (divePhase == 1 ? 1.12 : 1.65)
            let maxStep = maxSpeed * CGFloat(dt)
            penguinY += min(max(desiredStep, -maxStep), maxStep)
            if abs(delta) < 0.2 { penguinY = targetPenguinY }
        }

        // In the final approach, steer toward the player's requested height,
        // not merely the penguin's current height. This is what lets a late
        // switch win even while the character is still travelling between two
        // lanes. The force grows smoothly as the hoop arrives.
        let approachDistance = hoopX - penguinX
        if divePhase == 0, !resolved,
           approachDistance >= 0, approachDistance <= laneAssistDistance {
            let requestedLane = lanes.enumerated().min {
                abs($0.element - targetPenguinY) < abs($1.element - targetPenguinY)
            }?.offset ?? 1

            // Keep re-evaluating intent until there is only a very short,
            // speed-adjusted amount of travel left. From that point one lane
            // owns the passage, avoiding an ambiguous between-hoops result.
            if committedLaneIndex == nil, approachDistance <= laneCommitDistance {
                committedLaneIndex = requestedLane
            }

            let assistedLane = committedLaneIndex ?? requestedLane
            let laneY = lanes[assistedLane]
            let progress = 1 - approachDistance / laneAssistDistance
            var response = 7 + progress * progress * 16

            if committedLaneIndex != nil {
                // Once committed, converge to practically the lane centre by
                // the time the hoop centre reaches the penguin. The final-frame
                // placement removes the last sub-pixel ambiguity without a
                // visible teleport.
                let remainingTime = max(CGFloat(dt), approachDistance / max(1, approachSpeed))
                response = max(response, 4.8 / remainingTime)
                targetPenguinY = laneY
                if approachDistance <= approachSpeed * CGFloat(dt) * 1.05 {
                    penguinY = laneY
                }
            } else if dragStartY == nil {
                // With no finger down, let the same movement controller settle
                // too. A new drag still replaces this target until commitment.
                targetPenguinY = laneY
            }

            penguinY += (laneY - penguinY) * (1 - exp(-response * CGFloat(dt)))
        }

        // The surface itself decides when a splash is thrown, not the dive
        // state machine. Whatever moved the penguin across the line — a drag,
        // a tap, or a round resolving under water — the crossing is what is
        // measured, so a splash can no longer be skipped.
        updateSurfaceCrossing(dt: CGFloat(dt))

        if divePhase == 1, penguinY >= waterline + penguinSize * 0.10 {
            withAnimation(.easeInOut(duration: 0.26)) { divePhase = 2 }
        }

        if divePhase == 3 {
            // Keep the strong exit pose for the complete ascent. Only when
            // the player-selected height is reached do body and wings rotate
            // back into normal flight together.
            let reachedTarget = abs(targetPenguinY - penguinY) <= max(3, penguinSize * 0.018)
            if !surfaceSubmerged && reachedTarget {
                withAnimation(.easeInOut(duration: 0.30)) { divePhase = 4 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    if divePhase == 4 { divePhase = 0 }
                }
            }
        }

        guard isLive, !resolved, !shownOptions.isEmpty else { return }
        // Resolve only once the centres align: the penguin visibly travels
        // through the hoop instead of triggering against its leading edge.
        guard hoopX <= penguinX else { return }
        resolvePassage()
    }

    /// Moves everything that stands in the world on by one frame.
    ///
    /// The muzzle speed decays into the cruise speed along a single curve that
    /// keeps running across the hand-over, so the moment the player takes
    /// control is not a moment the world can be seen changing pace. An early
    /// ring tap accelerates the same conveyor, never the penguin's screen
    /// position.
    private func advanceWorld(dt: CGFloat) {
        let requested = cruiseSpeed * (speedRunActive && !resolved ? 2 : 1)
        var speed = requested
        if launchSpeedHandoffActive {
            launchGlideSpeed += (requested - launchGlideSpeed) * (1 - exp(-3.4 * dt))
            speed = launchGlideSpeed
            if abs(launchGlideSpeed - requested) < 1.5 {
                launchGlideSpeed = requested
                launchSpeedHandoffActive = false
            }
        }
        worldOffset -= speed * dt
        // The start marker is the starting line: the moment the penguin draws
        // level with it, the first set is put on the conveyor at the trailing
        // edge and rides in from there. Spawning it at the shot instead sent it
        // across the screen at the muzzle speed.
        if activeRoundID == nil, startMarkerX <= normalPenguinX {
            configureRound(force: true)
        }
        if launchPlatformActive, launchPlatformX < -sceneSize.width * 0.30 {
            launchPlatformActive = false
        }
        if startMarkerActive, startMarkerX < -penguinSize * 0.45 {
            startMarkerActive = false
        }
        for index in retiringSets.indices { retiringSets[index].x -= speed * dt }
        retiringSets.removeAll { $0.x < -hoopSize * 0.65 }
        if !shownOptions.isEmpty { hoopX -= speed * dt }
    }

    private func resolvePassage() {
        guard !resolved, let round = rounds.first else { return }
        withAnimation(.easeInOut(duration: 0.24)) { resolved = true }
        let selected: AnswerOption
        let isCorrect: Bool
        let usesSpeedBonus: Bool
        let usesHalfLifePenalty: Bool

        let isBelowRings = diveArmed || divePhase == 1 || divePhase == 2
        if isBelowRings, noCorrectAnswer, let correct = round.correctOption {
            selected = correct
            isCorrect = true
            usesHalfLifePenalty = false
            remainUnderwater()
        } else if isBelowRings, let wrong = round.options.first(where: { !$0.isCorrect }) {
            // Diving below a regular set deliberately misses every hoop.
            selected = wrong
            isCorrect = false
            usesHalfLifePenalty = true
            remainUnderwater()
        } else {
            let nearest = committedLaneIndex
                ?? lanes.enumerated().min {
                    abs($0.element - penguinY) < abs($1.element - penguinY)
                }?.offset
                ?? 1
            selected = shownOptions[min(nearest, shownOptions.count - 1)]
            isCorrect = selected.isCorrect
            usesHalfLifePenalty = false
        }

        usesSpeedBonus = speedBonusEligible && isCorrect
        if usesSpeedBonus {
            withAnimation(.easeInOut(duration: 0.20)) { goldenOptionID = selected.id }
        }

        onImpact()
        guard onHit(selected.id, usesSpeedBonus, usesHalfLifePenalty) else {
            resolved = false
            return
        }
        if !isCorrect {
            let solvedPrompt = round.question.solvedPrompt
            shownPrompt = solvedPrompt
            emphasizesCorrectAnswer = true
            showAnswerEcho(solvedPrompt)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if noCorrectAnswer && isCorrect { onDive() }
            else { onSwallow(isCorrect) }
        }
    }

    /// Passing a set underwater no longer launches an automatic exit. The
    /// penguin waits just below the surface until the player drags upward.
    private func remainUnderwater() {
        divePhase = 2
        penguinY = diveY
        targetPenguinY = diveY
    }

    /// Keeps the solved sum available after its moving set has passed without
    /// slowing or blocking the next set. A newer mistake replaces the older
    /// echo and owns its dismissal token.
    private func showAnswerEcho(_ prompt: String) {
        let echo = SolvedAnswerEcho(prompt: prompt)
        withAnimation(.easeOut(duration: 0.16)) { answerEcho = echo }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard answerEcho?.id == echo.id else { return }
            withAnimation(.easeOut(duration: 0.20)) { answerEcho = nil }
        }
    }

    /// Starts — or keeps — a dive. The height it begins from is recorded here
    /// because that, not the speed on the frame the surface happens to be
    /// crossed, is what the entry splash is sized by. Taking it at the moment
    /// the dive is armed also survives a round that resolves under water and
    /// puts the penguin below the line in a single step.
    private func armDive() {
        if divePhase != 1 && divePhase != 2 { diveStartY = penguinY }
        diveArmed = true
        if divePhase != 2 { divePhase = 1 }
        targetPenguinY = diveY
    }

    /// One splash per surface crossing, in either direction. The latch is on
    /// the penguin's position rather than on the dive state, so however it got
    /// under the line — dragged, tapped, or placed there by a resolved round —
    /// the water is always broken visibly.
    private func updateSurfaceCrossing(dt: CGFloat) {
        let level = waterline - penguinSize * 0.06
        let previous = previousPenguinY
        previousPenguinY = penguinY
        if !surfaceSubmerged, penguinY >= level {
            surfaceSubmerged = true
            emitSplash(.entering, strength: diveStrength)
        } else if surfaceSubmerged, penguinY <= level - penguinSize * 0.05 {
            surfaceSubmerged = false
            let climb = max(0, previous - penguinY) / max(dt, 1.0 / 240)
            emitSplash(.exiting, strength: climb / max(1, sceneSize.height * 1.5))
        }
    }

    /// How hard the penguin hit the water. A drop from the top of the flight
    /// window arrives at 1 and throws the full crown; a slip in from just above
    /// the surface still splashes, just modestly.
    private var diveStrength: CGFloat {
        let fall = waterline - diveStartY
        let span = max(1, waterline - flightMinY)
        return min(1, max(0.16, fall / span))
    }

    private func emitSplash(_ direction: WaterSplashDirection, strength: CGFloat) {
        let event = SplashEvent(direction: direction,
                                strength: min(1, max(0, strength)),
                                x: penguinX)
        splashes.append(event)
        // A cap, not a queue: rapid dives should overlap, not pile up.
        if splashes.count > 3 { splashes.removeFirst(splashes.count - 3) }
        let life = WaterSplash.life(direction: direction,
                                    strength: event.strength,
                                    reduceMotion: reduceMotion)
        DispatchQueue.main.asyncAfter(deadline: .now() + life + 0.05) {
            splashes.removeAll { $0.id == event.id }
        }
    }

    private func beginCompletion() {
        guard !completionActive else { return }
        completionSequence &+= 1
        let sequence = completionSequence
        completionStart = CGPoint(x: penguinX + completionLeadX, y: penguinY)
        completionActive = true
        completionProgress = 0
        completionLeadX = 0
        resolved = true

        // Preserve the final set as a retiring set before clearing the active
        // question. It can then drift out at conveyor speed throughout the
        // looping flight instead of vanishing on the hand-off frame.
        if !shownOptions.isEmpty, hoopX > -hoopSize * 0.65 {
            retiringSets.append(RetiringHoopSet(options: shownOptions,
                                                prompt: shownPrompt,
                                                x: hoopX,
                                                goldenOptionID: goldenOptionID))
        }
        shownOptions = []
        shownPrompt = ""
        previewOptions = []
        previewPrompt = ""
        previewRoundID = nil
        speedRunActive = false
        answerEcho = nil
        emphasizesCorrectAnswer = false
        diveArmed = false
        splashes = []
        surfaceSubmerged = false
        // The world stops for the finale, so anything still drifting out of
        // frame would stand frozen in it.
        launchPlatformActive = false
        startMarkerActive = false

        // Give the exit its own unhurried beat after the loop. At 2.4 seconds
        // the final screen-width was crossed in barely half a second, which
        // made an otherwise soft finale snap away at the end.
        let duration = reduceMotion ? 0.55 : 2.9
        withAnimation(.linear(duration: duration)) {
            completionProgress = 1
        }

        // Reveal the result once the penguin is almost beyond the trailing
        // edge. The remaining tail of the flight keeps running underneath the
        // card, so the animation stays smooth without making the player wait
        // for movement that is effectively already off-screen.
        let resultRevealProgress = 0.88
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * resultRevealProgress) {
            guard completionActive, completionSequence == sequence else { return }
            onLevelCompletionFinished()
        }
    }

    private func feedback(for optionID: UUID) -> HoopFeedback {
        // A set travelling in during the launch is never a resolved set: it has
        // not been played yet, so it must not wear an answer's colours.
        guard entranceStage >= 5 else { return .none }
        if resolved, goldenOptionID == optionID,
           shownOptions.first(where: { $0.id == optionID })?.isCorrect == true {
            return .golden
        }
        guard resolved,
              let option = shownOptions.first(where: { $0.id == optionID })
        else { return .none }
        if option.isCorrect, emphasizesCorrectAnswer { return .revealedCorrect }
        return option.isCorrect ? .correct : .wrong
    }
}

/// Carries the penguin through one full loop and then beyond the trailing edge.
/// Keeping the path inside an animatable modifier makes every intermediate
/// frame follow the curve instead of interpolating in a straight line between
/// a handful of state changes.
private struct CompletionFlightEffect: AnimatableModifier {
    var progress: CGFloat
    let sceneSize: CGSize
    let start: CGPoint
    let penguinSize: CGFloat
    let reduceMotion: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let sample = flightSample
        content
            .rotationEffect(.degrees(sample.rotation))
            .offset(sample.offset)
    }

    private var flightSample: (offset: CGSize, rotation: Double) {
        let p = min(1, max(0, progress))
        let exitX = sceneSize.width + penguinSize * 1.3 - start.x

        if reduceMotion {
            return (CGSize(width: exitX * smoothstep(p), height: 0), 0)
        }

        let leadEnd: CGFloat = 0.14
        // Reserve almost a third of the complete animation for the flight out
        // of frame. Combined with smoothstep this keeps both the hand-off from
        // the loop and the final disappearance calm and continuous.
        let loopEnd: CGFloat = 0.70
        let leadX = sceneSize.width * 0.06
        let radius = min(sceneSize.width * 0.13, sceneSize.height * 0.14)
        // Pull an underwater final answer back into clear sky before the loop,
        // while keeping an already-flying answer at a familiar height.
        let loopY = max(sceneSize.height * 0.38,
                        min(start.y, sceneSize.height * 0.70))
        let leadY = loopY - start.y

        if p < leadEnd {
            let t = smoothstep(p / leadEnd)
            let tilt = leadY < -1 ? -18 * Double(sin(t * .pi)) : 0
            return (CGSize(width: leadX * t, height: leadY * t), tilt)
        }

        if p < loopEnd {
            let t = (p - leadEnd) / (loopEnd - leadEnd)
            let angle = t * .pi * 2
            return (
                CGSize(width: leadX + radius * sin(angle),
                       height: leadY - radius * (1 - cos(angle))),
                -360 * Double(t)
            )
        }

        let t = smoothstep((p - loopEnd) / (1 - loopEnd))
        return (
            CGSize(width: leadX + (exitX - leadX) * t,
                   height: leadY - sceneSize.height * 0.035 * sin(t * .pi)),
            -360
        )
    }

    private func smoothstep(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
}

private enum PenguinPose: Equatable {
    case loaded
    case compressed
    case standing
    case launching
    case threading
    case flying
    case diving
    case underwater
    case resurfacing
    case recovering
}

private enum PenguinFlightMotion: Equatable { case rising, level, falling }

/// The three source canvases share exactly the same geometry. Keeping every
/// layer full-size preserves the artist's alignment; only each arm rotates
/// around its own fixed shoulder point.
private struct RiggedPenguin: View {
    let size: CGFloat
    let pose: PenguinPose
    let flightMotion: PenguinFlightMotion
    let reduceMotion: Bool
    let flightClock: Double

    var body: some View {
        let phase = flapPhase
        let transitionDuration: Double = pose == .diving ? 0.11 : (pose == .recovering ? 0.30 : 0.26)
        ZStack {
            rigImage("back_arm")
                .rotationEffect(.degrees(backArmAngle(phase: phase)),
                                anchor: UnitPoint(x: 0.715, y: 0.60))
                .animation(.easeInOut(duration: transitionDuration), value: pose)

            rigImage("main_body")

            rigImage("front_arm")
                .rotationEffect(.degrees(frontArmAngle(phase: phase)),
                                anchor: UnitPoint(x: 0.55, y: 0.55))
                .animation(.easeInOut(duration: transitionDuration), value: pose)
        }
        .frame(width: size * 1.5, height: size)
        .rotationEffect(.degrees(wholeBodyAngle))
        .scaleEffect(x: bodyScaleX, y: bodyScaleY)
        .allowsHitTesting(false)
    }

    private func rigImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .frame(width: size * 1.5, height: size)
    }

    private var flapPhase: Double {
        guard !reduceMotion, pose == .flying else { return 0 }
        let cyclesPerSecond: Double
        switch flightMotion {
        case .rising: cyclesPerSecond = 4
        case .level: cyclesPerSecond = 2.2
        case .falling: return 0
        }
        return sin(flightClock * .pi * 2 * cyclesPerSecond)
    }

    private var wholeBodyAngle: Double {
        switch pose {
        case .loaded, .compressed, .standing, .recovering: return 0
        case .launching: return -11
        case .threading: return 0
        case .diving: return 31
        case .underwater: return 5
        case .resurfacing: return -28
        case .flying:
            switch flightMotion {
            case .rising: return -11
            case .level: return 0
            case .falling: return 7
            }
        }
    }

    private var bodyScaleX: CGFloat {
        switch pose {
        case .loaded: return 0.84
        case .compressed: return 0.68
        default: return 1
        }
    }

    private var bodyScaleY: CGFloat { pose == .compressed ? 1.10 : 1 }

    private func backArmAngle(phase: Double) -> Double {
        switch pose {
        // The far wing points forward in the source artwork. A clockwise
        // rotation of roughly 210 degrees folds it toward the tail.
        case .launching: return 210
        case .threading: return 205
        case .compressed: return 190
        case .resurfacing: return 210
        case .recovering: return 0
        case .diving: return 4
        case .underwater: return 210
        case .loaded, .standing: return 0
        case .flying:
            switch flightMotion {
            case .rising: return phase * 34
            case .level: return phase * 14
            case .falling: return -7
            }
        }
    }

    private func frontArmAngle(phase: Double) -> Double {
        switch pose {
        // The near wing points backward in the source artwork, so neutral is
        // the tucked launch direction and +140 degrees reaches forward.
        case .launching: return -4
        case .threading: return -8
        case .compressed: return 8
        case .resurfacing: return -4
        case .recovering: return 0
        case .diving: return 140
        case .underwater: return -4
        case .loaded, .standing: return 0
        case .flying:
            switch flightMotion {
            case .rising: return -phase * 38
            case .level: return -phase * 16
            case .falling: return 8
            }
        }
    }
}

private enum CannonLaunchLayer: Equatable { case base, barrelForeground }

/// Normalized coordinates keep the fuse, flame, floe, and muzzle flash tied to
/// the cannon artwork even when its source texture is resized. The foreground
/// pass has a real opening cut from its mask, keeping the penguin behind the
/// barrel until it crosses the muzzle.
private struct CannonLaunchScene: View {
    let stage: Int
    let reduceMotion: Bool
    let layer: CannonLaunchLayer
    @State private var burnProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                if layer == .base {
                    cannonArtwork(width: width, height: height)

                    CannonFusePath()
                        .trim(from: burnProgress, to: 0.58)
                        .stroke(Color(red: 0.22, green: 0.10, blue: 0.035),
                                style: StrokeStyle(lineWidth: width * 0.026, lineCap: .round))

                    if stage < 2 {
                        FuseFlame(reduceMotion: reduceMotion)
                            .frame(width: width * 0.13, height: width * 0.16)
                            .scaleEffect(max(0.38, 1 - burnProgress * 0.72))
                            .position(fusePoint(progress: burnProgress, in: proxy.size))
                    }

                    if stage == 2 {
                        MuzzleFlash()
                            .frame(width: width * 0.29, height: width * 0.29)
                            .position(x: width * 0.88, y: height * 0.29)
                            .transition(.scale.combined(with: .opacity))
                    }
                } else {
                    cannonArtwork(width: width, height: height)
                        .mask(CannonBarrelMask().fill(.white,
                                                     style: FillStyle(eoFill: true)))
                }
            }
        }
        .onAppear {
            burnProgress = 0
            withAnimation(.linear(duration: reduceMotion ? 0.12 : 1.45)) {
                burnProgress = 0.58
            }
        }
    }

    private func cannonArtwork(width: CGFloat, height: CGFloat) -> some View {
        Image("canon")
            .resizable()
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .frame(width: width, height: height)
            .overlay {
                CannonFusePath()
                    .trim(from: 0, to: 0.60)
                    .stroke(.black,
                            style: StrokeStyle(lineWidth: width * 0.046,
                                               lineCap: .round))
                    .blendMode(.destinationOut)
                    .frame(width: width, height: height)
            }
            .compositingGroup()
            .scaleEffect(x: cannonScaleX, y: cannonScaleY, anchor: .bottomLeading)
    }

    private var cannonScaleX: CGFloat {
        if stage == 1 { return 0.86 }
        if stage == 2 { return 1.055 }
        return 1
    }

    private var cannonScaleY: CGFloat {
        if stage == 1 { return 1.06 }
        if stage == 2 { return 0.97 }
        return 1
    }

    private func fusePoint(progress: CGFloat, in size: CGSize) -> CGPoint {
        let start = CGPoint(x: size.width * 0.205, y: size.height * 0.255)
        let control = CGPoint(x: size.width * 0.225, y: size.height * 0.38)
        let end = CGPoint(x: size.width * 0.342, y: size.height * 0.375)
        let inverse = 1 - progress
        return CGPoint(x: inverse * inverse * start.x + 2 * inverse * progress * control.x + progress * progress * end.x,
                       y: inverse * inverse * start.y + 2 * inverse * progress * control.y + progress * progress * end.y)
    }
}

private struct CannonBarrelMask: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRect(CGRect(x: rect.width * 0.58,
                                y: rect.minY,
                                width: rect.width * 0.42,
                                height: rect.height))
            path.addEllipse(in: CGRect(x: rect.width * 0.755,
                                       y: rect.height * 0.165,
                                       width: rect.width * 0.145,
                                       height: rect.height * 0.25))
        }
    }
}

private struct CannonFusePath: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.205, y: rect.height * 0.255))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.342, y: rect.height * 0.375),
                              control: CGPoint(x: rect.width * 0.225, y: rect.height * 0.38))
        }
    }
}

private struct FuseFlame: View {
    let reduceMotion: Bool
    @State private var flickers = false

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.red)
                .shadow(color: .orange, radius: 9)
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.yellow)
                .scaleEffect(0.62)
                .offset(y: 4)
            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: 9, height: 9)
                .offset(y: 8)
        }
        .rotationEffect(.degrees(flickers ? 8 : -8))
        .scaleEffect(x: flickers ? 0.88 : 1.08, y: flickers ? 1.12 : 0.92)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.11).repeatForever(autoreverses: true),
                   value: flickers)
        .onAppear { flickers = true }
    }
}

private struct MuzzleFlash: View {
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color.yellow : Color.orange)
                    .frame(width: 10, height: 54)
                    .offset(y: -25)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            Circle().fill(.white).padding(18)
            Circle().stroke(.yellow.opacity(0.8), lineWidth: 8).padding(7)
        }
        .shadow(color: .orange, radius: 12)
    }
}

/// A small world-space reference that makes the camera follow readable. It
/// starts beside the cannon, floats on the surface, and leaves frame together
/// with the launch platform while the penguin settles at screen centre.
private struct FloatingStartMarker: View {
    let size: CGFloat
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0
                : sin(context.date.timeIntervalSinceReferenceDate * .pi * 1.7)
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(LinearGradient(colors: [.white,
                                                  Color(red: 0.56, green: 0.88, blue: 0.97)],
                                         startPoint: .top,
                                         endPoint: .bottom))
                    .overlay(Ellipse().stroke(.white.opacity(0.95), lineWidth: 2))
                    .frame(width: size, height: size * 0.30)
                    .shadow(color: .blue.opacity(0.25), radius: 4, y: 3)

                RoundedRectangle(cornerRadius: size * 0.025)
                    .fill(LinearGradient(colors: [.white, Color(red: 0.72, green: 0.84, blue: 0.91)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: size * 0.09, height: size * 1.12)
                    .offset(y: -size * 0.12)

                Image(systemName: "flag.checkered")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(red: 0.04, green: 0.24, blue: 0.52))
                    .frame(width: size * 0.58, height: size * 0.48)
                    .offset(x: size * 0.27, y: -size * 0.72)

                Circle()
                    .fill(.yellow)
                    .overlay(Circle().stroke(.orange, lineWidth: 2))
                    .frame(width: size * 0.17, height: size * 0.17)
                    .offset(y: -size * 1.13)
            }
            .frame(width: size * 1.35, height: size * 1.55)
            .rotationEffect(.degrees(phase * 2.2), anchor: .bottom)
            .offset(y: phase * size * 0.025)
        }
        .frame(width: size * 1.35, height: size * 1.55)
    }
}

/// World-space deadline for the optional 2× approach. Tap while this buoy is
/// still to the right of the penguin to earn the accelerated golden attempt.
private struct TurboTimingBuoy: View {
    let isAvailable: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(isAvailable ? Color.yellow : Color.white.opacity(0.55))
                    .overlay(Ellipse().stroke(.white.opacity(0.95), lineWidth: 2))
                    .frame(width: width, height: height * 0.30)

                Capsule()
                    .fill(isAvailable ? Color.orange : Color.gray.opacity(0.65))
                    .frame(width: width * 0.10, height: height * 0.78)
                    .offset(y: -height * 0.10)

                Image(systemName: "bolt.fill")
                    .font(.system(size: width * 0.35, weight: .black))
                    .foregroundStyle(isAvailable ? .yellow : .white.opacity(0.7))
                    .padding(width * 0.10)
                    .background(isAvailable ? Color.orange : Color.gray, in: Circle())
                    .offset(x: width * 0.28, y: -height * 0.47)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GoldenSpeedTrail: View {
    let size: CGFloat
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                // Three tapered-looking streamlines curl into the slipstream
                // instead of reading as rigid speed bars.
                ForEach(0..<3, id: \.self) { index in
                    let lane = CGFloat(index)
                    Path { path in
                        let startY = height * (0.25 + lane * 0.25)
                        let curl = (lane - 1) * height * 0.10
                        path.move(to: CGPoint(x: width * 0.96, y: startY))
                        path.addCurve(
                            to: CGPoint(x: width * (0.10 + lane * 0.05),
                                        y: startY + curl),
                            control1: CGPoint(x: width * 0.72,
                                              y: startY - curl * 0.65),
                            control2: CGPoint(x: width * 0.38,
                                              y: startY + curl * 1.35)
                        )
                    }
                    .trim(from: 0.05 + lane * 0.07, to: 1)
                    .stroke(index == 1 ? Color.yellow.opacity(0.80)
                                       : Color.white.opacity(0.68 - Double(index) * 0.08),
                            style: StrokeStyle(lineWidth: max(2, size * 0.032),
                                               lineCap: .round))
                }

                // A few drifting pressure droplets provide motion while using
                // the playfield's existing clock—no extra timer or blur pass.
                ForEach(0..<4, id: \.self) { index in
                    let travel = CGFloat((phase * (0.72 + Double(index) * 0.08)
                                          + Double(index) * 0.23)
                        .truncatingRemainder(dividingBy: 1))
                    let dotSize = max(3, size * (0.026 + CGFloat(index % 2) * 0.012))
                    let dotX = width * (0.88 - travel * 0.78)
                    let wave = sin(CGFloat(phase * 5) + CGFloat(index)) * height * 0.035
                    let dotY = height * (0.23 + CGFloat(index) * 0.18) + wave
                    let dotOpacity = Double(1 - travel) * 0.75 + 0.15
                    Circle()
                        .fill(index == 0 ? Color.yellow.opacity(0.82)
                                         : Color.white.opacity(0.74))
                        .frame(width: dotSize, height: dotSize)
                        .position(x: dotX, y: dotY)
                        .opacity(dotOpacity)
                }
            }
        }
        .frame(width: size * 1.55, height: size * 0.82)
        .allowsHitTesting(false)
    }
}

/// One splash, alive only for as long as it plays. Handing the renderer a list
/// of events rather than a pair of booleans is what guarantees a dive always
/// gets its splash: nothing later in the dive can clear a flag it needs.
private struct SplashEvent: Identifiable {
    let id = UUID()
    let direction: WaterSplashDirection
    /// 0…1, from the height the dive started at.
    let strength: CGFloat
    let x: CGFloat
}

private struct SolvedAnswerEcho: Identifiable {
    let id = UUID()
    let prompt: String
}

private struct RetiringHoopSet: Identifiable {
    let id = UUID()
    let options: [AnswerOption]
    let prompt: String
    var x: CGFloat
    let goldenOptionID: UUID?

    func feedback(for optionID: UUID) -> HoopFeedback {
        guard let option = options.first(where: { $0.id == optionID }) else { return .none }
        if option.isCorrect, goldenOptionID == optionID { return .golden }
        return option.isCorrect ? .correct : .wrong
    }
}

private enum HoopFeedback: Equatable { case none, correct, revealedCorrect, wrong, golden }

private struct MovingQuestionBadge: View {
    let prompt: String
    let character: AnimalCharacter
    let isPad: Bool

    var body: some View {
        Text(prompt)
            .font(.system(size: isPad ? 32 : 23, weight: .black, design: .rounded))
            .foregroundStyle(character.deepColor)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, isPad ? 23 : 17)
            .padding(.vertical, isPad ? 10 : 8)
            .background(.white.opacity(0.95), in: Capsule())
            .overlay(Capsule().stroke(character.color.opacity(0.42), lineWidth: 2))
            .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }
}

private struct SolvedAnswerEchoView: View {
    let prompt: String
    let character: AnimalCharacter
    let isPad: Bool

    var body: some View {
        Text(prompt)
            .font(.system(size: isPad ? 25 : 18, weight: .black, design: .rounded))
            .foregroundStyle(character.deepColor)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .padding(.horizontal, isPad ? 17 : 13)
            .padding(.vertical, isPad ? 8 : 6)
            .background(.white.opacity(0.90), in: Capsule())
            .overlay(Capsule().stroke(character.color.opacity(0.38), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
    }
}

private struct AnswerHoop: View {
    let text: String
    let tint: Color
    let size: CGFloat
    let feedback: HoopFeedback

    private var feedbackColor: Color {
        switch feedback {
        case .none: return .clear
        case .correct, .revealedCorrect: return .green
        case .wrong: return .red
        case .golden: return Color(red: 1.0, green: 0.70, blue: 0.05)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(tint, lineWidth: size * 0.13)
                .opacity(feedback == .none ? 1 : 0.18)

            Circle()
                .trim(from: 0.54, to: 0.92)
                .stroke(.white.opacity(0.68),
                        style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .padding(size * 0.035)
                .opacity(feedback == .none ? 1 : 0.28)

            Circle()
                .strokeBorder(feedbackColor, lineWidth: size * 0.13)
                .opacity(feedback == .none ? 0 : 1)
                .scaleEffect(feedback == .none ? 0.975 : 1)

            if feedback == .revealedCorrect {
                CorrectAnswerSweep(size: size)
            }

            Circle().strokeBorder(.white.opacity(0.75), lineWidth: 2)
                .padding(size * 0.09)
            Text(text)
                .font(.system(size: size * 0.29, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.04, green: 0.16, blue: 0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .allowsTightening(true)
                .padding(.horizontal, size * 0.12)
                .padding(.vertical, size * 0.06)
                .background(.white.opacity(0.94), in: Capsule())
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.28), value: feedback)
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
}

/// A thin highlight travels once around the existing correct hoop. It is
/// inset from the rim, so neither its stroke nor its animation can escape the
/// hoop's original frame.
private struct CorrectAnswerSweep: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.02, to: 0.24)
            .stroke(
                AngularGradient(colors: [.white.opacity(0.05), .white,
                                         Color.green.opacity(0.75), .white.opacity(0.05)],
                                center: .center),
                style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round)
            )
            .padding(size * 0.055)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                rotation = 0
                if reduceMotion {
                    rotation = 360
                } else {
                    withAnimation(.easeInOut(duration: 0.42)) { rotation = 360 }
                }
            }
            .allowsHitTesting(false)
    }
}

/// Near-side right arc of a hoop. It deliberately has no label or fill: those
/// stay on the back layer and remain readable while the penguin crosses it.
private struct AnswerHoopForeground: View {
    let tint: Color
    let size: CGFloat
    let feedback: HoopFeedback

    private var feedbackColor: Color {
        switch feedback {
        case .none: return .clear
        case .correct, .revealedCorrect: return .green
        case .wrong: return .red
        case .golden: return Color(red: 1.0, green: 0.70, blue: 0.05)
        }
    }

    var body: some View {
        ZStack {
            RightHalfHoopStroke(color: tint,
                                size: size,
                                lineWidth: size * 0.13)
                .opacity(feedback == .none ? 1 : 0.18)

            RightHalfHoopStroke(color: feedbackColor,
                                size: size,
                                lineWidth: size * 0.13)
                .opacity(feedback == .none ? 0 : 1)
                .scaleEffect(feedback == .none ? 0.975 : 1)

            RightHalfHoopStroke(color: .white.opacity(0.78),
                                size: size,
                                lineWidth: 2,
                                inset: size * 0.09)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.28), value: feedback)
        .allowsHitTesting(false)
    }
}

/// The right semicircle is the near side of the hoop. The complete hoop is
/// rendered behind the penguin; this masked duplicate alone is rendered above.
private struct RightHalfHoopStroke: View {
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    var inset: CGFloat = 0

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: lineWidth)
            .padding(inset)
            .mask {
                Rectangle()
                    .frame(width: size * 0.5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: size, height: size)
    }
}
