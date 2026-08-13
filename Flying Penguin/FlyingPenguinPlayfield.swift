import SwiftUI
import Combine

/// A stable, lifecycle-controlled source for simulation frames. Keeping the
/// publisher itself stable lets SwiftUI always invoke the current `tick`
/// closure, while stopping its upstream timer prevents 60 main-thread wakeups
/// per second behind pause/result cards or while the app is backgrounded.
private final class PlayfieldFrameClock {
    let ticks = PassthroughSubject<Date, Never>()
    private var subscription: AnyCancellable?

    func start() {
        guard subscription == nil else { return }
        let process = ProcessInfo.processInfo
        let usesReducedCadence = process.isLowPowerModeEnabled
            || process.thermalState == .serious
            || process.thermalState == .critical
        let interval = usesReducedCadence ? 1.0 / 30.0 : 1.0 / 60.0
        subscription = Timer.publish(every: interval,
                                     tolerance: interval * 0.08,
                                     on: .main,
                                     in: .common)
            .autoconnect()
            .sink { [weak self] in self?.ticks.send($0) }
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
    }

    deinit { stop() }
}

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
    /// What the guided run is teaching right now, and which rules it bends.
    /// A default plan is an ordinary session and costs the field nothing.
    var tutorial: TutorialPlan = TutorialPlan()
    var tutorialMessage: String? = nil
    /// How a lesson is answered: the field is the only place that knows how a
    /// passage, a drag or a tap actually ended.
    var onTutorialEvent: (TutorialEvent) -> Void = { _ in }
    /// True while the session's one rescue heart is owed to the next set.
    var isRescueHeartDue: Bool = false
    /// Raised the moment that heart is actually put in the world.
    var onRescueHeartPlaced: () -> Void = {}
    /// A heart in the flight path was flown into, at this point on screen.
    var onLifeHeartCollected: (CGPoint) -> Void = { _ in }
    /// How big a heart is drawn — the lives meter's own size, so the one that
    /// flies up to it neither grows nor shrinks on the way.
    var lifeHeartSize: CGFloat = 22
    let onHit: (UUID, Bool, Bool) -> Bool
    let onSwallow: (Bool) -> Void
    let onDive: () -> Void
    let onFishEntranceComplete: () -> Void
    let onLevelCompletionFinished: () -> Void

    @State private var frameClock = PlayfieldFrameClock()

    @State private var sceneSize: CGSize = .zero
    @State private var penguinY: CGFloat = 0
    @State private var targetPenguinY: CGFloat = 0
    @State private var dragStartY: CGFloat?
    @State private var pressHoldSequence = 0
    @State private var directPressActive = false
    @State private var suppressTapAfterPressHold = false
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
    @State private var bonusOptionID: UUID?
    /// Feedback follows the player's actual choice. Unchosen distractors stay
    /// neutral instead of turning red after a successful passage.
    @State private var selectedOptionID: UUID?
    @State private var bypassedWrongSet = false
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
    /// Every heart standing in the world: the ones the life lesson parks behind
    /// its wrong hoops, and the session's single rescue heart. They travel on
    /// the same conveyor as everything else, so they stay exactly where they
    /// were placed relative to the set they belong to.
    @State private var lifeHearts: [LifeHeartPickup] = []
    /// Guards the rescue heart against being placed twice in one frame, before
    /// the engine's answer to the first placement has come back.
    @State private var hasPlacedRescueHeart = false
    /// True while the turbo lesson is waiting for the player: the world stands
    /// still with the set and its tap hint in plain view.
    @State private var tutorialHold = false
    /// Set for the length of one set once its right hoop has been tapped. The
    /// lesson only ever waits for a tap that has not happened yet: without this
    /// a set tapped a moment before it reaches the holding point would stop
    /// dead with nothing left to ask for.
    @State private var tutorialTurboTapped = false

    // iPad's squarer playfield already gives the character more visual weight.
    // Retain a small tablet lift without letting it crowd the sum and water.
    private var penguinSize: CGFloat { sceneSize.height * (isPad ? 0.245 : 0.235) }
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
        // A squarer iPad viewport has a little less horizontal reading runway.
        // Give it roughly nine percent more time per set. Every moving world
        // layer reads this speed, so scenery, markers and hoops stay locked.
        let passageDuration: CGFloat = isPad ? 5.45 : 5
        return max(80, (sceneSize.width + hoopSize - normalPenguinX) / passageDuration)
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

                // The lesson parks a heart per wrong hoop, just behind it;
                // a rescue heart stands on its own, mid-way between two sets.
                ForEach(lifeHearts) { heart in
                    LifeHeartView(size: lifeHeartSize,
                                  tint: character.deepColor,
                                  reduceMotion: reduceMotion)
                        .position(x: heart.x, y: lanes[min(heart.lane, lanes.count - 1)])
                        .allowsHitTesting(false)
                }

                if speedRunActive && !resolved {
                    TurboSpeedWake(size: penguinSize, phase: flightClock)
                        .position(x: penguinX - penguinSize * 0.58, y: penguinY)
                        .transition(.opacity)
                }

                RiggedPenguin(size: penguinSize,
                              rig: CharacterRig.rig(for: character.id),
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

                // The tap hint sits above the hoop it is asking for, so "tap the
                // right hoop" has something to point at. It goes out the moment
                // the deadline is missed, because from there the tap is no
                // longer the one being taught.
                if tutorial.highlightsTurbo, !resolved, entranceStage >= 5,
                   let index = correctHoopIndex,
                   timingMarkerX(for: hoopX) > penguinX {
                    TutorialTapPulse(size: hoopSize * 0.86,
                                     tint: character.deepColor,
                                     reduceMotion: reduceMotion)
                        .position(x: hoopX, y: lanes[index])
                        .allowsHitTesting(false)
                }

                if let tutorialMessage, let symbol = tutorial.step?.symbolName,
                   entranceStage >= 5 {
                    // Low and only as wide as the sentence needs. The card is
                    // given nearly the whole width to play with so its one line
                    // stays one line; the cap is what the type then shrinks to
                    // fit, and a short lesson still gets a short card.
                    TutorialMessageCard(text: tutorialMessage,
                                        symbolName: symbol,
                                        theme: character,
                                        isPad: isPad)
                        .frame(maxWidth: proxy.size.width * 0.94)
                        .padding(.bottom, bottomReserve + (isPad ? 8 : 5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottom)
                        // Every touch belongs to the flight: the lesson must
                        // never swallow the tap it is asking for.
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(flightGesture)
            .simultaneousGesture(playfieldTapGesture)
            .onAppear {
                updateLayout(proxy.size)
                if playsFishEntrance { beginEntrance() }
                else { resolved = true }
                updateFrameClock(running: isRunning)
            }
            .onChange(of: proxy.size) { _, value in updateLayout(value) }
        }
        .ignoresSafeArea()
        .onReceive(frameClock.ticks, perform: tick)
        .onChange(of: isRunning) { _, running in
            updateFrameClock(running: running)
        }
        .onDisappear {
            frameClock.stop()
            lastTick = nil
        }
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
        .onChange(of: tutorial) { _, _ in applyTutorialPlan() }
    }

    private func updateFrameClock(running: Bool) {
        if running {
            // Never fold time spent paused into the next physics step.
            lastTick = nil
            frameClock.start()
        } else {
            frameClock.stop()
            lastTick = nil
        }
    }

    /// A step change rewrites what a set is allowed to be. A lesson hands over
    /// during the beat between one passage and the next sum being installed, so
    /// the set that carries the new rules is the one still waiting off-screen —
    /// nothing changes under the penguin's nose.
    private func applyTutorialPlan() {
        tutorialHold = false
        tutorialTurboTapped = false
        // The lesson's own hearts go with it. Whatever is left of them when it
        // hands over — the untaken one of a pair, or a set placed just before
        // the tutorial finished — is cleared, so the real game never starts
        // with a free life floating in it. A rescue heart is nobody's lesson
        // and stays where it is.
        if !tutorial.placesHearts { lifeHearts.removeAll(where: \.isLesson) }
        if tutorial.hidesHoops {
            shownOptions = []
            shownPrompt = ""
            previewOptions = []
            previewPrompt = ""
            previewRoundID = nil
            activeRoundID = nil
            lifeHearts.removeAll(where: \.isLesson)
            resolved = false
            return
        }
        guard entranceStage >= 3, sceneSize.width > 0 else { return }
        guard !shownOptions.isEmpty else {
            // Coming out of the two movement lessons: the first real set is put
            // on the conveyor at the trailing edge and rides in from there.
            configureRound(force: true)
            return
        }
        // The set on its way in is the one the new step gets to shape. It is
        // taken over wholesale when the round turns over, so re-tuning it here
        // is what puts the lesson's rules on the very next hoops the player
        // meets.
        configurePreview()
        // The set already in frame keeps whatever it was dealt: swapping three
        // answers in plain sight is worse than one set of the old shape.
        guard !resolved, hoopX > sceneSize.width, let round = rounds.first else { return }
        let presented = presentation(for: round)
        shownOptions = presented.options
        noCorrectAnswer = presented.hasNoCorrectAnswer
        placeTutorialHearts()
    }

    /// The world this character flies across. Same flight, same cannon, same
    /// rings — a different place to do it in.
    private var scenery: SceneryTheme { SceneryThemes.theme(for: character.id) }

    private var polarBackdrop: some View {
        ZStack {
            PolarSkyLayer(size: sceneSize, worldOffset: worldOffset, theme: scenery)
            SceneryHorizonBand(size: sceneSize,
                               waterline: waterline,
                               worldOffset: worldOffset,
                               theme: scenery)
            PolarWaterBackdrop(size: sceneSize,
                               waterline: waterline,
                               worldOffset: worldOffset,
                               isPad: isPad,
                               theme: scenery)
        }
        .clipped()
        .allowsHitTesting(false)
    }

    /// Everything that floats between the water's two halves. Drawn before the
    /// rings and under the water foreground, so the wash sinks the lower half
    /// of every object for free.
    private var movingWorld: some View {
        DriftingFloaters(size: sceneSize,
                         waterline: waterline,
                         worldOffset: worldOffset,
                         isPad: isPad,
                         depth: .behind,
                         theme: scenery)
    }

    private var waterForeground: some View {
        ZStack {
            PolarWaterForeground(size: sceneSize,
                                 waterline: waterline,
                                 worldOffset: worldOffset,
                                 isPad: isPad,
                                 theme: scenery)
            DriftingFloaters(size: sceneSize,
                             waterline: waterline,
                             worldOffset: worldOffset,
                             isPad: isPad,
                             depth: .front,
                             theme: scenery,
                             // A foreground object directly below a ring stack
                             // reads as a solid obstacle. Keep that gameplay
                             // corridor visually open, including while an old
                             // set is drifting out after an answer.
                             exclusionXs: [foregroundHoopAnchorX],
                             exclusionSpacing: ringSetSpacing)
        }
    }

    /// A virtual first-ring corridor that is attached to the conveyor before
    /// the first set exists. The real set is installed when the start marker
    /// reaches the penguin; at that instant this anchor lands on `ringSpawnX`.
    /// Keeping it alive before then prevents near-water items from blinking as
    /// the launch changes from an empty field to its first set of hoops.
    private var foregroundHoopAnchorX: CGFloat {
        ringSpawnX + launchCameraOffset + startMarkerLead
    }

    private var startMarkerLead: CGFloat {
        sceneSize.width * 0.58 - normalPenguinX
    }

    /// The cannon stands on the pad's deck, so both are placed from the same
    /// number: raise or lower one and the other follows.
    private var cannonWidth: CGFloat { sceneSize.width * 0.269 }
    private var cannonHeight: CGFloat { sceneSize.width * 0.179 }
    private var launchPadHeight: CGFloat {
        // Keep the launch rock as low and wide as the iPhone version. Scaling
        // its width and height from different screen axes made it much taller
        // on iPad's squarer viewport, which lifted the cannon onto a high peak.
        min(sceneSize.height * 0.17, sceneSize.width * 0.0785)
    }

    private var cannonCentreY: CGFloat {
        guard isPad else { return sceneSize.height * 0.735 }
        // `canon.png` has transparent padding below the wheels: the last solid
        // artwork row is 586 in a 683-pixel image. Anchor that visible edge,
        // rather than the frame edge, to the levelled deck. This remains exact
        // at every iPad preview size and avoids another screenshot-based offset.
        let deckY = waterline
            - launchPadHeight * (PolarScene.padWaterline - PolarScene.padDeckFraction)
        let visibleWheelBottom = CGFloat(586) / CGFloat(683)
        let wheelOffsetFromCentre = cannonHeight * (visibleWheelBottom - 0.5)
        let contactOverlap = min(3, launchPadHeight * 0.035)
        return deckY - wheelOffsetFromCentre + contactOverlap
    }

    /// The character and the cannon share one launch origin. Any iPad deck
    /// correction therefore also moves the loaded pose and the first frame of
    /// the flight, keeping the character inside the barrel until departure.
    private var cannonMuzzleY: CGFloat {
        cannonCentreY - cannonHeight * 0.22
    }

    private var cannonLaunch: some View {
        CannonLaunchScene(stage: entranceStage,
                          reduceMotion: reduceMotion,
                          layer: .base)
            .frame(width: cannonWidth, height: cannonHeight)
            .position(x: launchPlatformX, y: cannonCentreY)
            .allowsHitTesting(false)
    }

    private var cannonForeground: some View {
        CannonLaunchScene(stage: entranceStage,
                          reduceMotion: reduceMotion,
                          layer: .barrelForeground)
            .frame(width: cannonWidth, height: cannonHeight)
            .position(x: launchPlatformX, y: cannonCentreY)
            .allowsHitTesting(false)
    }

    /// Drawn after the sea, not with the cannon. The launch site is the nearest
    /// thing in the world; behind the water it was hidden by whichever floe
    /// happened to be drifting past — and since both travel at the same speed,
    /// that floe stayed in the way for the whole entrance.
    private var cannonPlatform: some View {
        let height = launchPadHeight
        return CannonLaunchPad(theme: scenery)
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

    private var acceptsVerticalControl: Bool {
        let canSurface = (1...4).contains(divePhase)
        return isRunning && entranceStage >= 5 && !completionActive
            && (isLive || canSurface) && (!resolved || canSurface)
            && committedLaneIndex == nil
    }

    private var flightGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard acceptsVerticalControl else { return }
                // The choice remains live throughout the assist zone. Only the
                // short commit zone at the hoop itself stops accepting a new
                // lane, so a late drag can still redirect an in-flight penguin.
                if dragStartY == nil {
                    dragStartY = targetPenguinY == 0 ? penguinY : targetPenguinY
                    directPressActive = false
                    beginPressHold(at: value.startLocation)
                }

                let distance = hypot(value.translation.width, value.translation.height)
                if distance > 8, !directPressActive {
                    // The player started dragging before the hold completed.
                    // Invalidate its delayed callback and retain relative drag.
                    pressHoldSequence += 1
                }

                if directPressActive {
                    movePenguinToward(y: value.location.y)
                } else {
                    // Movement is relative to where the penguin was when the
                    // drag began. A stationary hold deliberately switches to
                    // the absolute finger height after a short delay.
                    let requested = (dragStartY ?? penguinY) + value.translation.height
                    movePenguinToward(y: requested)
                }
                reportDraggedHeight()
            }
            .onEnded { _ in
                let completedPressHold = directPressActive
                pressHoldSequence += 1
                directPressActive = false
                dragStartY = nil
                if completedPressHold {
                    suppressTapAfterPressHold = true
                    DispatchQueue.main.async {
                        suppressTapAfterPressHold = false
                    }
                }
            }
    }

    private func beginPressHold(at location: CGPoint) {
        pressHoldSequence += 1
        let sequence = pressHoldSequence
        guard location.x < hoopX - hoopSize * 0.72 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard pressHoldSequence == sequence, dragStartY != nil,
                  acceptsVerticalControl else { return }
            directPressActive = true
            movePenguinToward(y: location.y)
        }
    }

    private var playfieldTapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in handlePlayfieldTap(at: value.location) }
    }

    private func handlePlayfieldTap(at location: CGPoint) {
        guard !directPressActive, !suppressTapAfterPressHold else { return }
        // Tapping at or beyond the active hoops keeps the existing turbo lane
        // selection. Everywhere before that zone is direct, unboosted height
        // control: the penguin smoothly flies to the tapped vertical position.
        // With no set on the conveyor at all — the two movement lessons — every
        // tap is a height tap, wherever the retired hoops happen to stand.
        if !shownOptions.isEmpty, location.x >= hoopX - hoopSize * 0.72 {
            handleRingTap(at: location)
        } else {
            handleHeightTap(at: location)
        }
    }

    private func handleHeightTap(at location: CGPoint) {
        guard acceptsVerticalControl else { return }

        dragStartY = nil
        reportTappedHeight(at: location)
        movePenguinToward(y: location.y)
    }

    /// The first lesson asks for a low point and a high point. Which half of
    /// the flight band the penguin has been *sent to* is what counts, so the
    /// step is satisfied by the drag itself rather than by waiting for the
    /// character to finish travelling there.
    private func reportDraggedHeight() {
        guard tutorial.tracksDrag else { return }
        let span = flightMaxY - flightMinY
        guard span > 1 else { return }
        if targetPenguinY >= flightMinY + span * 0.62 {
            onTutorialEvent(.draggedLow)
        } else if targetPenguinY <= flightMinY + span * 0.38 {
            onTutorialEvent(.draggedHigh)
        }
    }

    /// The second lesson is about the penguin, not about the screen: a tap
    /// counts as "under me" or "above me" relative to where it is flying.
    private func reportTappedHeight(at location: CGPoint) {
        guard tutorial.tracksTaps else { return }
        let margin = penguinSize * 0.30
        if location.y > penguinY + margin {
            onTutorialEvent(.tappedBelow)
        } else if location.y < penguinY - margin {
            onTutorialEvent(.tappedAbove)
        }
    }

    private func movePenguinToward(y requestedY: CGFloat) {
        let canSurface = (1...4).contains(divePhase)
        if requestedY >= waterline {
            // While flying itself is being taught the water is off limits: the
            // penguin flattens out along the bottom of the flight band instead
            // of diving out of the lesson.
            guard !tutorial.blocksDiving else {
                diveArmed = false
                divePhase = 0
                targetPenguinY = flightMaxY
                return
            }
            armDive()
            return
        }

        diveArmed = false
        if canSurface {
            if divePhase != 4 { divePhase = 3 }
        } else {
            divePhase = 0
        }
        targetPenguinY = min(max(requestedY, flightMinY), flightMaxY)
    }

    private func handleRingTap(at location: CGPoint) {
        guard isLive, isRunning, entranceStage >= 5, !resolved,
              committedLaneIndex == nil,
              location.x >= hoopX - hoopSize * 0.72 else { return }

        if location.y > lanes[2] + hoopSize * 0.46 {
            // The held set is waiting for one specific tap; nothing else — a
            // dive included — may take the lesson off its rails.
            guard !tutorialHold else { return }
            dragStartY = nil
            activateTurbo()
            speedBonusEligible = timingMarkerX(for: hoopX) > penguinX
            guard !tutorial.blocksDiving else { return }
            armDive()
            return
        }

        let lane = lanes.enumerated().min {
            abs($0.element - location.y) < abs($1.element - location.y)
        }?.offset ?? 1
        // While the turbo lesson holds the world still, only the hoop it is
        // pointing at releases it. Anything else leaves the set standing.
        if lane == correctHoopIndex {
            tutorialTurboTapped = true
            tutorialHold = false
        } else if tutorialHold {
            return
        }

        dragStartY = nil
        activateTurbo()
        speedBonusEligible = timingMarkerX(for: hoopX) > penguinX

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

    /// A valid early ring tap doubles the conveyor speed for this set. Keep the
    /// sound on the state transition so repeated touches cannot stack it.
    private func activateTurbo() {
        guard !speedRunActive else { return }
        speedRunActive = true
        AppAudio.shared.playTurbo()
    }

    /// Which of the three hoops carries the answer, if any of them does.
    private var correctHoopIndex: Int? {
        shownOptions.firstIndex { $0.isCorrect }
    }

    /// Where a held set comes to a stop: fully in frame, and still comfortably
    /// on the near side of its own deadline, so the tap that releases it is the
    /// early tap the lesson is asking for.
    private var tutorialHoldX: CGFloat { sceneSize.width * 0.78 }

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
        // The muzzle's own height, so the character leaves the barrel rather
        // than appearing beside it. It follows every iPad deck correction.
        case 0, 1, 2: return cannonMuzzleY
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
        bonusOptionID = nil
        selectedOptionID = nil
        bypassedWrongSet = false
        launchSpeedHandoffActive = false
        launchGlideSpeed = 0
        launchWorldOrigin = worldOffset
        launchPlatformActive = true
        startMarkerActive = true
        lifeHearts = []
        hasPlacedRescueHeart = false
        tutorialHold = false
        tutorialTurboTapped = false
        AppAudio.shared.playFireCrackle()
        let fuseDuration = reduceMotion ? 0.12 : 1.45
        let squeezeDuration = reduceMotion ? 0.06 : 0.24
        let flightDuration = reduceMotion ? 0.10 : 0.72
        DispatchQueue.main.asyncAfter(deadline: .now() + fuseDuration * 0.72) {
            withAnimation(.spring(response: squeezeDuration, dampingFraction: 0.58)) { entranceStage = 1 }
        }
        // Schedule just ahead of the visual frame: the trimmed effect keeps a
        // tiny natural attack, so its boom lands on the muzzle flash itself.
        let cannonSoundLead: TimeInterval = 0.035
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, fuseDuration - cannonSoundLead)) {
            AppAudio.shared.playCannonShoot()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fuseDuration) {
            AppAudio.shared.stopFireCrackle()
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
        // The first two lessons are about flying and nothing else: no set is
        // put on the conveyor at all until the hoops are introduced.
        guard !tutorial.hidesHoops else { return }
        guard force || activeRoundID != round.id else { return }
        let promotesPreview = previewRoundID == round.id
        let promotedX = previewX
        if !shownOptions.isEmpty, hoopX > -hoopSize * 0.65 {
            retiringSets.append(makeRetiringSet())
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
        bonusOptionID = nil
        selectedOptionID = nil
        bypassedWrongSet = false
        emphasizesCorrectAnswer = false
        tutorialTurboTapped = false
        placeTutorialHearts()
        placeRescueHeartIfDue()
        // Keep the exact flight height between sets. Only a completed dive
        // changes it as part of its resurfacing sequence.
    }

    /// Parks a heart just behind every wrong hoop of the set being introduced.
    /// Behind, because the conveyor runs right to left: a heart placed further
    /// out arrives after the hoop it belongs to, which is exactly what makes it
    /// reachable only to a penguin that has just flown through that hoop.
    private func placeTutorialHearts() {
        guard tutorial.placesHearts, !shownOptions.isEmpty else { return }
        let offset = hoopSize * 0.95
        lifeHearts.removeAll { $0.isLesson && $0.setID == activeRoundID }
        lifeHearts += shownOptions.enumerated().compactMap { index, option in
            guard !option.isCorrect else { return nil }
            return LifeHeartPickup(setID: activeRoundID,
                                   lane: index,
                                   x: hoopX + offset,
                                   isLesson: true)
        }
    }

    /// The session's one rescue heart, placed halfway between the set that is
    /// arriving and the one before it, in the lane the answer is in — so the
    /// line that takes the player to the heart is the same line that takes them
    /// through the right hoop. A set with no right answer has no such lane and
    /// simply waits for the next one.
    private func placeRescueHeartIfDue() {
        guard isRescueHeartDue, !hasPlacedRescueHeart,
              !tutorial.isRunning, !shownOptions.isEmpty,
              let lane = correctHoopIndex else { return }
        hasPlacedRescueHeart = true
        lifeHearts.append(LifeHeartPickup(setID: activeRoundID,
                                          lane: lane,
                                          x: hoopX - ringSetSpacing * 0.5,
                                          isLesson: false))
        onRescueHeartPlaced()
    }

    /// A heart is taken when the penguin reaches it in the lane it is sitting
    /// in. Under water it is out of reach, which is the point.
    private func collectLifeHearts() {
        guard !lifeHearts.isEmpty, divePhase != 1, divePhase != 2 else { return }
        let reach = hoopSize * 0.46
        guard let taken = lifeHearts.first(where: { heart in
            guard heart.lane < lanes.count else { return false }
            return abs(heart.x - penguinX) <= reach
                && abs(lanes[heart.lane] - penguinY) <= hoopSize * 0.44
        }) else { return }
        lifeHearts.removeAll { $0.id == taken.id }
        onLifeHeartCollected(CGPoint(x: penguinX, y: lanes[taken.lane]))
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
        // A lesson decides what its own set has to be: three wrong answers
        // while diving underneath is being taught, one right answer for every
        // step after it. Everything else is left to chance, as in a real run.
        var hasNoCorrectAnswer = seed.isMultiple(of: 4)
        if tutorial.forcesNoCorrectAnswer { hasNoCorrectAnswer = true }
        if tutorial.forcesCorrectAnswer { hasNoCorrectAnswer = false }
        let wrong = round.options.filter { !$0.isCorrect }
        if hasNoCorrectAnswer {
            return (Array(wrong.prefix(3)), true)
        }
        guard let correct = round.correctOption else { return (Array(wrong.prefix(3)), false) }
        let choices = [correct] + Array(wrong.prefix(2))
        // A lesson may ask for the answer in the top hoop; ordinary play rotates
        // it so no lane is ever the safe bet.
        guard !tutorial.putsAnswerOnTop else { return (choices, false) }
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
        // The turbo lesson stops the conveyor once the player has had their
        // three free sets: the hoops and the tap hint stand still until the
        // right one is tapped. Only the world waits — the penguin keeps flying,
        // and every touch keeps being answered.
        if tutorial.holdsForTurbo, !tutorialHold, !resolved, !tutorialTurboTapped,
           !shownOptions.isEmpty, hoopX <= tutorialHoldX {
            tutorialHold = true
        }
        if !tutorialHold { advanceWorld(dt: CGFloat(dt)) }

        guard entranceStage >= 5 else { return }
        collectLifeHearts()
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
        // The lesson's hearts ride the same conveyor as the set they were
        // placed behind, so the gap between hoop and heart never changes.
        if !lifeHearts.isEmpty {
            for index in lifeHearts.indices { lifeHearts[index].x -= speed * dt }
            lifeHearts.removeAll { $0.x < -hoopSize * 0.65 }
        }
        if !shownOptions.isEmpty { hoopX -= speed * dt }
    }

    private func resolvePassage() {
        guard !resolved, let round = rounds.first else { return }
        withAnimation(.easeInOut(duration: 0.24)) { resolved = true }
        let selected: AnswerOption
        let isCorrect: Bool
        let usesSpeedBonus: Bool
        let usesHalfLifePenalty: Bool

        // Treat the visible flight path as authoritative too. During a quick
        // resurfacing the dive phase may already have advanced while the
        // penguin is still physically below the complete hoop stack.
        let isBelowRings = diveArmed || divePhase == 1 || divePhase == 2
            || penguinY > lanes[2] + hoopSize * 0.46
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
        guard onHit(selected.id, usesSpeedBonus, usesHalfLifePenalty) else {
            resolved = false
            return
        }
        // A regular set passed underneath still needs a wrong option for the
        // game engine to apply its penalty, but no hoop was actually touched.
        // Keep that synthetic choice out of the visual feedback so only the
        // revealed correct hoop turns green; red remains reserved for a wrong
        // hoop the penguin really flew through.
        // What the passage was is only knowable here: the engine is told an
        // option, but whether the penguin threaded a hoop or went underneath
        // the lot is the field's own business — and it is the whole difference
        // between the lessons being taught.
        if tutorial.isRunning {
            if isBelowRings {
                onTutorialEvent(.passedUnderSet)
            } else if isCorrect {
                onTutorialEvent(.passedCorrectHoop(withTurbo: usesSpeedBonus))
            } else {
                onTutorialEvent(.passedWrongHoop)
            }
        }
        selectedOptionID = isBelowRings ? nil : selected.id
        bypassedWrongSet = isBelowRings && noCorrectAnswer && isCorrect
        if usesSpeedBonus {
            withAnimation(.easeInOut(duration: 0.20)) { bonusOptionID = selected.id }
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
            AppAudio.shared.playSplash()
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
            retiringSets.append(makeRetiringSet())
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
        lifeHearts = []
        tutorialHold = false
        tutorialTurboTapped = false
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
        if resolved, bypassedWrongSet { return .bypassed }
        if resolved, bonusOptionID == optionID,
           shownOptions.first(where: { $0.id == optionID })?.isCorrect == true {
            return .bonus
        }
        guard resolved,
              let option = shownOptions.first(where: { $0.id == optionID })
        else { return .none }
        if selectedOptionID == optionID {
            return option.isCorrect ? .correct : .wrong
        }
        if option.isCorrect, emphasizesCorrectAnswer { return .revealedCorrect }
        return .inactive
    }

    /// Freeze the resolved visual state before the next set replaces the
    /// active options. This preserves a successful all-wrong dive as neutral
    /// blue instead of recomputing every old option as a mistake.
    private func makeRetiringSet() -> RetiringHoopSet {
        let feedbacks = Dictionary(uniqueKeysWithValues: shownOptions.map {
            ($0.id, feedback(for: $0.id))
        })
        return RetiringHoopSet(options: shownOptions,
                               prompt: shownPrompt,
                               x: hoopX,
                               feedbacks: feedbacks)
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
    let rig: CharacterRig
    let pose: PenguinPose
    let flightMotion: PenguinFlightMotion
    let reduceMotion: Bool
    let flightClock: Double

    var body: some View {
        let phase = flapPhase
        let transitionDuration: Double = pose == .diving ? 0.11 : (pose == .recovering ? 0.30 : 0.26)
        ZStack {
            rigImage(rig.backArmImage)
                .rotationEffect(.degrees(backArmAngle(phase: phase)),
                                anchor: rig.backShoulder)
                .animation(.easeInOut(duration: transitionDuration), value: pose)

            rigImage(rig.bodyImage)

            rigImage(rig.frontArmImage)
                .rotationEffect(.degrees(frontArmAngle(phase: phase)),
                                anchor: rig.frontShoulder)
                .animation(.easeInOut(duration: transitionDuration), value: pose)
        }
        .frame(width: size * 1.5, height: size)
        // Normalise the drawing before the pose is applied, so every rotation
        // below still turns around the body rather than around the canvas.
        .scaleEffect(rig.artScale)
        .offset(x: size * 1.5 * rig.artOffset.width, y: size * rig.artOffset.height)
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

private struct TurboSpeedWake: View {
    let size: CGFloat
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                // Soft, filled wind ribbons taper into the slipstream. Their
                // translucent area reads as moving air rather than speed bars.
                ForEach(0..<2, id: \.self) { index in
                    let lane = CGFloat(index)
                    Path { path in
                        let centreY = height * (0.35 + lane * 0.30)
                        let thickness = height * (index == 0 ? 0.14 : 0.11)
                        let tailY = centreY + (lane == 0 ? -height * 0.12 : height * 0.10)
                        path.move(to: CGPoint(x: width * 0.98, y: centreY - thickness * 0.30))
                        path.addCurve(
                            to: CGPoint(x: width * (0.04 + lane * 0.06), y: tailY),
                            control1: CGPoint(x: width * 0.70, y: centreY - thickness),
                            control2: CGPoint(x: width * 0.30, y: tailY - thickness * 0.55)
                        )
                        path.addCurve(
                            to: CGPoint(x: width * 0.98, y: centreY + thickness * 0.30),
                            control1: CGPoint(x: width * 0.32, y: tailY + thickness * 0.40),
                            control2: CGPoint(x: width * 0.72, y: centreY + thickness)
                        )
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [
                        Color.white.opacity(0.04),
                        Color.cyan.opacity(0.18),
                        Color.mint.opacity(index == 0 ? 0.44 : 0.30),
                        Color.white.opacity(0.58)
                    ], startPoint: .leading, endPoint: .trailing))
                }

                // Larger sparkles replace the tiny pressure droplets. They use
                // the playfield clock, so turbo adds no timer or blur pass.
                ForEach(0..<5, id: \.self) { index in
                    let travel = CGFloat((phase * (0.60 + Double(index) * 0.055)
                                          + Double(index) * 0.19)
                        .truncatingRemainder(dividingBy: 1))
                    let sparkleSize = max(7, size * (0.058 + CGFloat(index % 3) * 0.014))
                    let sparkleX = width * (0.90 - travel * 0.82)
                    let wave = sin(CGFloat(phase * 4.2) + CGFloat(index) * 1.7) * height * 0.055
                    let sparkleY = height * (0.22 + CGFloat(index) * 0.145) + wave
                    let sparkleOpacity = Double(1 - travel) * 0.72 + 0.22
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                        .font(.system(size: sparkleSize, weight: .bold))
                        .foregroundStyle(index == 1 ? Color.yellow.opacity(0.92)
                                                    : Color.white.opacity(0.90))
                        .rotationEffect(.degrees(Double(index * 29) + phase * 42))
                        .scaleEffect(0.82 + 0.18 * sin(CGFloat(phase * 6) + CGFloat(index)))
                        .position(x: sparkleX, y: sparkleY)
                        .opacity(sparkleOpacity)
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

/// One heart standing in the world: behind the wrong hoop of the life lesson,
/// or alone in the gap between two sets as the session's rescue. It carries its
/// own position rather than an offset from a set, so the next set arriving
/// cannot drag it along with it.
private struct LifeHeartPickup: Identifiable {
    let id = UUID()
    /// The round whose set this heart was placed with.
    let setID: UUID?
    let lane: Int
    var x: CGFloat
    /// True for the hearts the guided run puts out, which go when it ends.
    let isLesson: Bool
}

/// A life waiting in the flight path. Deliberately the very same heart the
/// lives meter is drawn with — the character's deep colour behind a soft white
/// outline — so what it gives back needs no explaining.
private struct LifeHeartView: View {
    let size: CGFloat
    let tint: Color
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0
                : sin(context.date.timeIntervalSinceReferenceDate * .pi * 2.4)
            LifeHeartGlyph(size: size, tint: tint)
                .scaleEffect(1 + phase * 0.08)
                .shadow(color: .black.opacity(0.20), radius: 5, y: 3)
        }
        .frame(width: size, height: size)
    }
}

/// Asks for a tap, on the one hoop the turbo lesson is about. Rings leave the
/// rim while a hand stands off to the right, pointing back at it — off to the
/// side deliberately, because a hand in the middle of the hoop covers the one
/// thing the player has to read: the answer.
private struct TutorialTapPulse: View {
    let size: CGFloat
    let tint: Color
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let clock = context.date.timeIntervalSinceReferenceDate
            let nudge = reduceMotion ? 0 : CGFloat(sin(clock * .pi * 2.4))
            ZStack {
                ForEach(0..<2, id: \.self) { index in
                    let progress = reduceMotion ? 0.45
                        : CGFloat((clock * 0.9 + Double(index) * 0.5)
                            .truncatingRemainder(dividingBy: 1))
                    Circle()
                        .stroke(tint.opacity(Double(1 - progress) * 0.75),
                                lineWidth: size * 0.07)
                        .scaleEffect(0.42 + progress * 0.72)
                }

                // The hand taps toward the rim: it sits just outside the hoop's
                // right edge and leans into it, so the eye is led from the hand
                // to the ring rather than away from it.
                Image(systemName: "hand.point.left.fill")
                    .font(.system(size: size * 0.34, weight: .black))
                    .foregroundStyle(tint)
                    .padding(size * 0.09)
                    .background(.white.opacity(0.94), in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                    .offset(x: size * (0.66 - 0.05 * nudge))
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

private struct RetiringHoopSet: Identifiable {
    let id = UUID()
    let options: [AnswerOption]
    let prompt: String
    var x: CGFloat
    let feedbacks: [UUID: HoopFeedback]

    func feedback(for optionID: UUID) -> HoopFeedback {
        feedbacks[optionID] ?? .none
    }
}

private enum HoopFeedback: Equatable {
    case none, inactive, correct, revealedCorrect, wrong, bonus, bypassed
}

private struct MovingQuestionBadge: View {
    let prompt: String
    let character: AnimalCharacter
    let isPad: Bool

    var body: some View {
        Text(prompt)
            .font(.system(size: isPad ? 36 : 23, weight: .black, design: .rounded))
            .foregroundStyle(character.deepColor)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, isPad ? 25 : 17)
            .padding(.vertical, isPad ? 11 : 8)
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

    private var feedbackGradient: AngularGradient {
        switch feedback {
        case .correct, .revealedCorrect, .bonus:
            return AngularGradient(colors: [
                Color(red: 0.12, green: 0.78, blue: 0.36),
                Color(red: 0.57, green: 0.94, blue: 0.39),
                Color(red: 0.04, green: 0.62, blue: 0.39),
                Color(red: 0.12, green: 0.78, blue: 0.36)
            ], center: .center)
        case .wrong:
            return AngularGradient(colors: [
                Color(red: 0.96, green: 0.22, blue: 0.30),
                Color(red: 1.00, green: 0.48, blue: 0.28),
                Color(red: 0.82, green: 0.12, blue: 0.38),
                Color(red: 0.96, green: 0.22, blue: 0.30)
            ], center: .center)
        case .bypassed:
            return AngularGradient(colors: [
                Color.white.opacity(0.82), Color.cyan.opacity(0.72),
                Color.blue.opacity(0.45), Color.white.opacity(0.82)
            ], center: .center)
        case .none, .inactive:
            return AngularGradient(colors: [.clear, .clear], center: .center)
        }
    }

    private var showsResolvedRim: Bool { feedback != .none && feedback != .inactive }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(tint, lineWidth: size * 0.13)
                .opacity(feedback == .none ? 1 : (feedback == .inactive ? 0.42 : 0.16))

            Circle()
                .trim(from: 0.54, to: 0.92)
                .stroke(.white.opacity(0.68),
                        style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .padding(size * 0.035)
                .opacity(feedback == .none ? 1 : (feedback == .inactive ? 0.38 : 0.24))

            Circle()
                .strokeBorder(feedbackGradient, lineWidth: size * 0.13)
                .opacity(showsResolvedRim ? 1 : 0)
                .scaleEffect(showsResolvedRim ? 1 : 0.975)

            if feedback == .correct || feedback == .revealedCorrect || feedback == .wrong || feedback == .bonus {
                FeedbackRimSweep(size: size, feedback: feedback)
            }

            if feedback == .bonus {
                BonusStarBurst(size: size)
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

/// One compact glint makes a complete lap around a resolved rim. It animates
/// only once, keeping the result lively without leaving a permanent spinner.
private struct FeedbackRimSweep: View {
    let size: CGFloat
    let feedback: HoopFeedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.02, to: 0.24)
            .stroke(
                AngularGradient(colors: [.white.opacity(0.02), .white.opacity(0.96),
                                         sweepTint.opacity(0.70), .white.opacity(0.02)],
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

    private var sweepTint: Color {
        feedback == .wrong ? .orange : .mint
    }
}

/// The turbo reward stays green like a normal correct answer, then adds one
/// small outward star pop so the bonus is unmistakable without a gold rim.
private struct BonusStarBurst: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * 45 - 90
                Image(systemName: index.isMultiple(of: 2) ? "star.fill" : "sparkle")
                    .font(.system(size: size * (index.isMultiple(of: 2) ? 0.105 : 0.085),
                                  weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 3) ? Color.yellow : Color.white)
                    .shadow(color: Color.green.opacity(0.30), radius: 2)
                    .offset(y: -size * (0.38 + progress * 0.22))
                    .rotationEffect(.degrees(angle))
                    .opacity(Double(1 - progress * 0.82))
                    .scaleEffect(0.62 + progress * 0.46)
            }
        }
        .onAppear {
            progress = reduceMotion ? 0.55 : 0
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.48)) { progress = 1 }
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

    private var feedbackGradient: AngularGradient {
        switch feedback {
        case .correct, .revealedCorrect, .bonus:
            return AngularGradient(colors: [.green, .mint, Color(red: 0.04, green: 0.62, blue: 0.39), .green],
                                   center: .center)
        case .wrong:
            return AngularGradient(colors: [.red, .orange, Color(red: 0.82, green: 0.12, blue: 0.38), .red],
                                   center: .center)
        case .bypassed:
            return AngularGradient(colors: [.white.opacity(0.82), .cyan.opacity(0.72),
                                             .blue.opacity(0.45), .white.opacity(0.82)],
                                   center: .center)
        case .none, .inactive:
            return AngularGradient(colors: [.clear, .clear], center: .center)
        }
    }

    private var showsResolvedRim: Bool { feedback != .none && feedback != .inactive }

    var body: some View {
        ZStack {
            RightHalfHoopStroke(color: tint,
                                size: size,
                                lineWidth: size * 0.13)
                .opacity(feedback == .none ? 1 : (feedback == .inactive ? 0.42 : 0.18))

            Circle()
                .strokeBorder(feedbackGradient, lineWidth: size * 0.13)
                .mask {
                    Rectangle()
                        .frame(width: size * 0.5)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .opacity(showsResolvedRim ? 1 : 0)
                .scaleEffect(showsResolvedRim ? 1 : 0.975)

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
