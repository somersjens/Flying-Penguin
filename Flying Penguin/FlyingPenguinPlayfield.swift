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
    /// Invalidates a delayed finale callback when a fresh run starts.
    @State private var completionSequence = 0
    @State private var lastTick: Date?
    @State private var launchGlideSpeed: CGFloat = 0
    @State private var launchSpeedHandoffActive = false
    @State private var startMarkerActive = false
    @State private var startMarkerWorldOrigin: CGFloat = 0
    @State private var entrySplashShown = false
    @State private var exitSplashShown = false
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
        // Let the leading rim enter on the very first gameplay frame. The set
        // is still hidden throughout the cannon sequence, but there is no
        // empty beat once control is handed to the player.
        sceneSize.width + hoopSize * 0.30
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

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                polarBackdrop

                movingWorld

                if entranceStage >= 5 && !completionActive {
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

                if entranceStage < 5 && playsFishEntrance {
                    cannonLaunch
                }

                if startMarkerActive && playsFishEntrance {
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

                if !previewOptions.isEmpty && entranceStage >= 5 && !completionActive {
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

                if !shownOptions.isEmpty && entranceStage >= 5 && !completionActive {
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
                    .opacity(entranceStage < 3 ? 0 : 1)
                    .position(x: completionActive ? completionStart.x : displayedPenguinX,
                              y: completionActive ? completionStart.y : displayedPenguinY)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 4)
                    .allowsHitTesting(false)

                // A second, near-side half of every hoop sits above the
                // penguin. The complete hoop below plus this arc above makes
                // the character visibly pass through the opening.
                hoopForegrounds

                if entranceStage < 5 && playsFishEntrance {
                    cannonForeground
                }

                waterForeground

                if entrySplashShown && (divePhase == 1 || divePhase == 2) {
                    WaterSplash(direction: .entering, reduceMotion: reduceMotion)
                        .frame(width: penguinSize * 1.48, height: penguinSize * 0.82)
                        .position(x: penguinX, y: waterline)
                        .allowsHitTesting(false)
                }

                if exitSplashShown {
                    WaterSplash(direction: .exiting, reduceMotion: reduceMotion)
                        .frame(width: penguinSize * 1.22, height: penguinSize * 0.70)
                        .position(x: penguinX, y: waterline)
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
        .onChange(of: playsLevelCompletion) { _, value in if value { beginCompletion() } }
    }

    private var polarBackdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.68, green: 0.88, blue: 1),
                                    Color(red: 0.91, green: 0.97, blue: 1)],
                           startPoint: .top, endPoint: .bottom)
            Circle().fill(.white.opacity(0.55)).blur(radius: 24)
                .frame(width: sceneSize.width * 0.28)
                .position(x: sceneSize.width * 0.78, y: sceneSize.height * 0.22)
            ForEach(0..<6, id: \.self) { index in
                Capsule().fill(.white.opacity(0.28))
                    .frame(width: sceneSize.width * 0.18, height: isPad ? 8 : 5)
                    .position(x: scrollingX(index: index),
                              y: sceneSize.height * (0.18 + CGFloat(index % 3) * 0.16))
            }
            waterBackdrop
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private var movingWorld: some View {
        ForEach(0..<5, id: \.self) { index in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 9))
                path.addLine(to: CGPoint(x: 22, y: 0))
                path.addLine(to: CGPoint(x: 46, y: 9))
                path.addLine(to: CGPoint(x: 68, y: 2))
                path.addLine(to: CGPoint(x: 94, y: 10))
            }
            .stroke(Color.white.opacity(0.55), lineWidth: 3)
            .frame(width: 94, height: 12)
            .position(x: scrollingX(index: index), y: waterline + 28 + CGFloat(index % 2) * 25)
        }
    }

    private var waterBackdrop: some View {
        let depth = max(0, sceneSize.height - waterline + 12)
        return ZStack {
            WaterBodyShape()
                .fill(LinearGradient(colors: [Color(red: 0.26, green: 0.82, blue: 0.94),
                                              Color(red: 0.05, green: 0.47, blue: 0.78),
                                              Color(red: 0.02, green: 0.22, blue: 0.57)],
                                     startPoint: .top, endPoint: .bottom))
            ForEach(0..<4, id: \.self) { index in
                WaveEdge()
                    .stroke(Color.white.opacity(0.28 - Double(index) * 0.045),
                            style: StrokeStyle(lineWidth: isPad ? 4 : 2.5, lineCap: .round))
                    .frame(height: 11)
                    .offset(y: 10 + CGFloat(index) * 13)
            }
        }
        .frame(width: sceneSize.width, height: depth)
        .position(x: sceneSize.width * 0.5, y: waterline + depth * 0.5 - 9)
    }

    private var waterForeground: some View {
        let depth = max(0, sceneSize.height - waterline + 14)
        return ZStack(alignment: .top) {
            WaterBodyShape()
                .fill(LinearGradient(colors: [Color.cyan.opacity(0.42),
                                              Color(red: 0.02, green: 0.38, blue: 0.70).opacity(0.78)],
                                     startPoint: .top, endPoint: .bottom))
            WaveEdge()
                .stroke(.white.opacity(0.94),
                        style: StrokeStyle(lineWidth: isPad ? 7 : 5, lineCap: .round))
                .frame(height: 17)
                .offset(y: 1)
                .shadow(color: .cyan.opacity(0.55), radius: 4, y: 2)
            WaveEdge()
                .stroke(Color(red: 0.39, green: 0.91, blue: 1).opacity(0.72),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(height: 13)
                .offset(y: 10)
        }
        .frame(width: sceneSize.width, height: depth)
        .position(x: sceneSize.width * 0.5, y: waterline + depth * 0.5 - 8)
        .allowsHitTesting(false)
    }

    private var cannonLaunch: some View {
        CannonLaunchScene(stage: entranceStage,
                          reduceMotion: reduceMotion,
                          layer: .base)
            .frame(width: sceneSize.width * 0.269,
                   height: sceneSize.width * 0.179)
            .position(x: sceneSize.width * 0.145 + launchCameraOffset,
                      y: sceneSize.height * 0.79)
            .allowsHitTesting(false)
    }

    private var cannonForeground: some View {
        CannonLaunchScene(stage: entranceStage,
                          reduceMotion: reduceMotion,
                          layer: .barrelForeground)
            .frame(width: sceneSize.width * 0.269,
                   height: sceneSize.width * 0.179)
            .position(x: sceneSize.width * 0.145 + launchCameraOffset,
                      y: sceneSize.height * 0.79)
            .allowsHitTesting(false)
    }

    private var launchCameraOffset: CGFloat {
        switch entranceStage {
        case 0, 1, 2: return 0
        default: return -sceneSize.width * 0.46
        }
    }

    private var startMarkerX: CGFloat {
        let gameplayDrift = entranceStage >= 5
            ? worldOffset - startMarkerWorldOrigin
            : 0
        return sceneSize.width * 0.58 + launchCameraOffset + gameplayDrift
    }

    private var flightGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let canSurface = (1...4).contains(divePhase)
                guard isRunning, entranceStage >= 5, !completionActive,
                      (isLive || canSurface), (!resolved || canSurface) else { return }
                // Any fresh movement reopens the choice, even inside the final
                // approach zone. The lane is only committed while the finger
                // is released.
                committedLaneIndex = nil
                if dragStartY == nil { dragStartY = targetPenguinY == 0 ? penguinY : targetPenguinY }
                // Movement is relative to where the penguin was when the drag
                // began. Touching elsewhere on screen therefore never makes it
                // jump to the finger.
                let requested = (dragStartY ?? penguinY) + value.translation.height
                if requested >= waterline {
                    if divePhase != 1 { entrySplashShown = false }
                    exitSplashShown = false
                    diveArmed = true
                    if divePhase != 2 { divePhase = 1 }
                    targetPenguinY = diveY
                } else {
                    diveArmed = false
                    if canSurface {
                        // Enter the ascent once; repeated drag events only
                        // adjust its destination and never restart the pose.
                        if divePhase != 3 && divePhase != 4 {
                            exitSplashShown = false
                        }
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
              location.x >= hoopX - hoopSize * 0.72 else { return }

        committedLaneIndex = nil
        dragStartY = nil
        let isEarly = timingMarkerX(for: hoopX) > penguinX
        speedRunActive = true
        speedBonusEligible = isEarly

        if location.y > lanes[2] + hoopSize * 0.46 {
            entrySplashShown = false
            exitSplashShown = false
            diveArmed = true
            divePhase = 1
            targetPenguinY = diveY
            return
        }

        let lane = lanes.enumerated().min {
            abs($0.element - location.y) < abs($1.element - location.y)
        }?.offset ?? 1
        if divePhase == 1 || divePhase == 2 || divePhase == 3 {
            divePhase = 3
            exitSplashShown = false
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
        case 0, 1, 2: return sceneSize.height * 0.70
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
        if !shownOptions.isEmpty && entranceStage >= 5 && !completionActive,
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
        }
        if hoopX == 0 { hoopX = ringSpawnX }
    }

    private func beginEntrance() {
        completionSequence &+= 1
        completionActive = false
        completionProgress = 0
        completionStart = .zero
        entranceStage = 0
        resolved = true
        shownOptions = []
        shownPrompt = ""
        previewOptions = []
        previewPrompt = ""
        previewRoundID = nil
        retiringSets = []
        activeRoundID = nil
        hoopX = ringSpawnX
        penguinX = normalPenguinX
        penguinY = lanes[1]
        targetPenguinY = penguinY
        dragStartY = nil
        noCorrectAnswer = false
        diveArmed = false
        divePhase = 0
        committedLaneIndex = nil
        entrySplashShown = false
        exitSplashShown = false
        lastTick = nil
        flightClock = 0
        speedRunActive = false
        speedBonusEligible = false
        goldenOptionID = nil
        launchSpeedHandoffActive = false
        startMarkerActive = true
        startMarkerWorldOrigin = worldOffset
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
            launchGlideSpeed = sceneSize.width * 1.25
            withAnimation(.timingCurve(0.12, 0.72, 0.78, 0.88,
                                       duration: flightDuration)) { entranceStage = 3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fuseDuration + 0.10 + flightDuration) {
            startMarkerWorldOrigin = worldOffset
            launchSpeedHandoffActive = true
            withAnimation(.easeOut(duration: reduceMotion ? 0.03 : 0.08)) { entranceStage = 5 }
            configureRound(force: true)
            resolved = false
            onFishEntranceComplete()
        }
    }

    private func configureRound(force: Bool) {
        guard entranceStage >= 5, let round = rounds.first, sceneSize.width > 0 else { return }
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
            return
        }

        if entranceStage == 3 || entranceStage == 4 {
            let blend = 1 - exp(-3.2 * CGFloat(dt))
            launchGlideSpeed += (cruiseSpeed - launchGlideSpeed) * blend
            worldOffset -= launchGlideSpeed * dt
            return
        }
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

        // Only assist in the final fraction of the approach and never while
        // the player is actively moving. A last-moment drag can therefore
        // switch lane right up to the hoop centre.
        let approachDistance = hoopX - penguinX
        let assistDistance = hoopSize * (dragStartY == nil ? 0.42 : 0.16)
        if divePhase == 0, !resolved,
           approachDistance >= 0, approachDistance <= assistDistance {
            if committedLaneIndex == nil {
                committedLaneIndex = lanes.enumerated().min {
                    abs($0.element - penguinY) < abs($1.element - penguinY)
                }?.offset
            }
            if let committedLaneIndex {
                let laneY = lanes[committedLaneIndex]
                let progress = 1 - approachDistance / assistDistance
                let response = 6 + progress * 11
                penguinY += (laneY - penguinY) * (1 - exp(-response * CGFloat(dt)))
                targetPenguinY = laneY
            }
        }

        if divePhase == 1, !entrySplashShown,
           penguinY >= waterline - penguinSize * 0.08 {
            entrySplashShown = true
        }
        if divePhase == 1, penguinY >= waterline + penguinSize * 0.10 {
            withAnimation(.easeInOut(duration: 0.26)) { divePhase = 2 }
        }

        if divePhase == 3 {
            if !exitSplashShown,
               penguinY <= waterline - penguinSize * 0.05 {
                exitSplashShown = true
            }

            // Keep the strong exit pose for the complete ascent. Only when
            // the player-selected height is reached do body and wings rotate
            // back into normal flight together.
            let reachedTarget = abs(targetPenguinY - penguinY) <= max(3, penguinSize * 0.018)
            if exitSplashShown && reachedTarget {
                withAnimation(.easeInOut(duration: 0.30)) { divePhase = 4 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    if divePhase == 4 {
                        divePhase = 0
                        exitSplashShown = false
                    }
                }
            }
        }

        // Resolve only once the centres align: the penguin visibly travels
        // through the hoop instead of triggering against its leading edge.
        let contactX = penguinX
        let baseSpeed = cruiseSpeed
        // An early ring tap accelerates the conveyor, never the penguin's
        // screen position. It ends exactly at the hoop centre.
        let speedMultiplier: CGFloat = speedRunActive && !resolved ? 2 : 1
        let requestedSpeed = baseSpeed * speedMultiplier
        let speed: CGFloat
        if launchSpeedHandoffActive {
            // Continue the launch velocity into gameplay and ease it down to
            // cruise speed. Switching straight to cruise produced the small
            // but perceptible hitch at the first set.
            let blend = 1 - exp(-5.8 * CGFloat(dt))
            launchGlideSpeed += (requestedSpeed - launchGlideSpeed) * blend
            speed = launchGlideSpeed
            if abs(launchGlideSpeed - requestedSpeed) < 1.5 {
                launchGlideSpeed = requestedSpeed
                launchSpeedHandoffActive = false
            }
        } else {
            speed = requestedSpeed
        }
        worldOffset -= speed * dt
        if startMarkerActive, startMarkerX < -penguinSize * 0.45 {
            startMarkerActive = false
        }
        for index in retiringSets.indices { retiringSets[index].x -= speed * dt }
        retiringSets.removeAll { $0.x < -hoopSize * 0.65 }
        guard !shownOptions.isEmpty else { return }
        hoopX -= speed * dt

        guard isLive, !resolved else { return }

        guard hoopX <= contactX else { return }
        resolvePassage()
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

    private func beginCompletion() {
        guard !completionActive else { return }
        completionSequence &+= 1
        let sequence = completionSequence
        completionStart = CGPoint(x: penguinX, y: penguinY)
        completionActive = true
        completionProgress = 0
        resolved = true
        shownOptions = []
        shownPrompt = ""
        previewOptions = []
        previewPrompt = ""
        previewRoundID = nil
        retiringSets = []
        speedRunActive = false
        diveArmed = false
        entrySplashShown = false
        exitSplashShown = false

        // Give the exit its own unhurried beat after the loop. At 2.4 seconds
        // the final screen-width was crossed in barely half a second, which
        // made an otherwise soft finale snap away at the end.
        let duration = reduceMotion ? 0.55 : 2.9
        withAnimation(.linear(duration: duration)) {
            completionProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            guard completionActive, completionSequence == sequence else { return }
            onLevelCompletionFinished()
        }
    }

    private func scrollingX(index: Int) -> CGFloat {
        guard sceneSize.width > 0 else { return 0 }
        let spacing = sceneSize.width / 4
        let raw = worldOffset * 0.22 + CGFloat(index) * spacing
        let span = sceneSize.width + spacing
        let wrapped = raw.truncatingRemainder(dividingBy: span)
        return wrapped < 0 ? wrapped + span : wrapped
    }

    private func feedback(for optionID: UUID) -> HoopFeedback {
        if resolved, goldenOptionID == optionID,
           shownOptions.first(where: { $0.id == optionID })?.isCorrect == true {
            return .golden
        }
        guard resolved,
              let option = shownOptions.first(where: { $0.id == optionID })
        else { return .none }
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
                    IceFloeView()
                        .frame(width: width * 0.94, height: height * 0.29)
                        .position(x: width * 0.48, y: height * 0.89)

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
                ZStack {
                    CannonFusePath()
                        .trim(from: 0, to: 0.60)
                        .stroke(.black,
                                style: StrokeStyle(lineWidth: width * 0.046,
                                                   lineCap: .round))
                        .blendMode(.destinationOut)

                    Capsule()
                        .fill(RadialGradient(colors: [.yellow, .orange,
                                                      Color(red: 0.48, green: 0.20, blue: 0.02)],
                                             center: .topLeading,
                                             startRadius: 1,
                                             endRadius: width * 0.035))
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.9), lineWidth: 2))
                        .frame(width: width * 0.12, height: width * 0.075)
                        .rotationEffect(.degrees(-8))
                        .position(x: width * 0.31, y: height * 0.368)
                }
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

private struct IceFloeView: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                IceFloeUnderside()
                    .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.78, blue: 0.92),
                                                  Color(red: 0.06, green: 0.40, blue: 0.70)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(IceFloeUnderside()
                        .stroke(Color(red: 0.20, green: 0.65, blue: 0.86), lineWidth: 2))

                IceFloe()
                    .fill(LinearGradient(colors: [.white,
                                                  Color(red: 0.84, green: 0.97, blue: 1),
                                                  Color(red: 0.55, green: 0.86, blue: 0.96)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .overlay(IceFloe().stroke(.white.opacity(0.98), lineWidth: 3))

                IceFloeFacets()
                    .stroke(Color(red: 0.16, green: 0.68, blue: 0.88).opacity(0.42),
                            style: StrokeStyle(lineWidth: 2,
                                               lineCap: .round,
                                               lineJoin: .round))

                Capsule()
                    .fill(.white.opacity(0.92))
                    .frame(width: width * 0.70, height: max(3, height * 0.055))
                    .position(x: width * 0.47, y: height * 0.31)

                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(0.88 - Double(index) * 0.16))
                        .frame(width: width * (0.025 + CGFloat(index) * 0.006))
                        .position(x: width * (0.24 + CGFloat(index) * 0.24),
                                  y: height * (0.24 + CGFloat(index % 2) * 0.08))
                }
            }
        }
        .shadow(color: .blue.opacity(0.28), radius: 8, y: 5)
    }
}

private struct IceFloe: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.03, y: rect.height * 0.43))
            path.addCurve(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.20),
                          control1: CGPoint(x: rect.width * 0.06, y: rect.height * 0.30),
                          control2: CGPoint(x: rect.width * 0.10, y: rect.height * 0.22))
            path.addCurve(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.19),
                          control1: CGPoint(x: rect.width * 0.38, y: rect.height * 0.08),
                          control2: CGPoint(x: rect.width * 0.65, y: rect.height * 0.10))
            path.addCurve(to: CGPoint(x: rect.width * 0.98, y: rect.height * 0.42),
                          control1: CGPoint(x: rect.width * 0.92, y: rect.height * 0.23),
                          control2: CGPoint(x: rect.width * 0.97, y: rect.height * 0.32))
            path.addCurve(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.61),
                          control1: CGPoint(x: rect.width, y: rect.height * 0.52),
                          control2: CGPoint(x: rect.width * 0.93, y: rect.height * 0.58))
            path.addCurve(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.63),
                          control1: CGPoint(x: rect.width * 0.62, y: rect.height * 0.70),
                          control2: CGPoint(x: rect.width * 0.35, y: rect.height * 0.70))
            path.addCurve(to: CGPoint(x: rect.width * 0.03, y: rect.height * 0.43),
                          control1: CGPoint(x: rect.width * 0.08, y: rect.height * 0.59),
                          control2: CGPoint(x: rect.width * 0.02, y: rect.height * 0.51))
            path.closeSubpath()
        }
    }
}

private struct IceFloeUnderside: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.46))
            path.addLine(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.72))
            path.addLine(to: CGPoint(x: rect.width * 0.31, y: rect.height * 0.69))
            path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.94))
            path.addLine(to: CGPoint(x: rect.width * 0.54, y: rect.height * 0.70))
            path.addLine(to: CGPoint(x: rect.width * 0.68, y: rect.height * 0.87))
            path.addLine(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.66))
            path.addLine(to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.45))
            path.closeSubpath()
        }
    }
}

private struct IceFloeFacets: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.20))
            path.addLine(to: CGPoint(x: rect.width * 0.31, y: rect.height * 0.61))
            path.addLine(to: CGPoint(x: rect.width * 0.46, y: rect.height * 0.15))
            path.move(to: CGPoint(x: rect.width * 0.31, y: rect.height * 0.61))
            path.addLine(to: CGPoint(x: rect.width * 0.61, y: rect.height * 0.65))
            path.addLine(to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.14))
            path.move(to: CGPoint(x: rect.width * 0.61, y: rect.height * 0.65))
            path.addLine(to: CGPoint(x: rect.width * 0.86, y: rect.height * 0.24))
        }
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

private enum HoopFeedback: Equatable { case none, correct, wrong, golden }

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

private struct AnswerHoop: View {
    let text: String
    let tint: Color
    let size: CGFloat
    let feedback: HoopFeedback

    private var feedbackColor: Color {
        switch feedback {
        case .none: return .clear
        case .correct: return .green
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

            Circle().strokeBorder(.white.opacity(0.75), lineWidth: 2)
                .padding(size * 0.09)
            Text(text)
                .font(.system(size: size * 0.29, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.04, green: 0.16, blue: 0.38))
                .padding(.horizontal, size * 0.12)
                .padding(.vertical, size * 0.06)
                .background(.white.opacity(0.94), in: Capsule())
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.28), value: feedback)
        .drawingGroup(opaque: false, colorMode: .nonLinear)
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
        case .correct: return .green
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

private struct WaveEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        let wavelength: CGFloat = 52
        var x = rect.minX
        while x < rect.maxX {
            path.addCurve(to: CGPoint(x: x + wavelength, y: rect.midY),
                          control1: CGPoint(x: x + wavelength * 0.25, y: rect.minY),
                          control2: CGPoint(x: x + wavelength * 0.75, y: rect.maxY))
            x += wavelength
        }
        return path
    }
}

private struct WaterBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amplitude: CGFloat = min(9, rect.height * 0.22)
        let wavelength: CGFloat = 58
        path.move(to: CGPoint(x: rect.minX, y: amplitude))
        var x = rect.minX
        while x < rect.maxX {
            path.addCurve(to: CGPoint(x: x + wavelength, y: amplitude),
                          control1: CGPoint(x: x + wavelength * 0.25, y: 0),
                          control2: CGPoint(x: x + wavelength * 0.75, y: amplitude * 2))
            x += wavelength
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private enum WaterSplashDirection: Equatable { case entering, exiting }

private struct WaterSplash: View {
    let direction: WaterSplashDirection
    let reduceMotion: Bool
    @State private var expanded = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let lift = height * (direction == .exiting ? 0.78 : 0.54)
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
                               height: height * (direction == .exiting ? 0.34 : 0.25))
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
    }
}
