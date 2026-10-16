import SwiftUI

/// Animation values for one owl flight: lift, wing flaps, and a lean into the direction of travel.
struct OwlFlightPose {
  var lift: Double = 0
  var wing: Double = 0
  var tilt: Double = 0
  var scale: Double = 1
  /// Vertical squash for the crouch before take-off and the bounce on landing.
  var squash: Double = 1
}

extension View {
  /// Plays a flight (or hop) whenever `trigger` changes.
  func owlFlight(trigger: Int, direction: Double = 1, height: Double = 46, isEnabled: Bool = true) -> some View {
    modifier(OwlFlightModifier(trigger: trigger, direction: direction, height: height, isEnabled: isEnabled))
  }
}

private struct OwlFlightModifier: ViewModifier {
  var trigger: Int
  var direction: Double
  var height: Double
  var isEnabled: Bool

  func body(content: Content) -> some View {
    if isEnabled {
      content.keyframeAnimator(initialValue: OwlFlightPose(), trigger: trigger) { view, pose in
        view
          .environment(\.owlWingSpread, pose.wing)
          .scaleEffect(x: 2 - pose.squash, y: pose.squash, anchor: .bottom)
          .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
          .scaleEffect(pose.scale, anchor: .bottom)
          .offset(y: -pose.lift)
      } keyframes: { _ in
        // A slower, more natural flight: crouch, push off, a few deep wing beats, glide, flare, land.
        KeyframeTrack(\.squash) {
          CubicKeyframe(0.9, duration: 0.18)
          SpringKeyframe(1.05, duration: 0.25, spring: .smooth)
          CubicKeyframe(1, duration: 1.2)
          CubicKeyframe(0.93, duration: 0.15)
          SpringKeyframe(1, duration: 0.45, spring: .bouncy)
        }
        KeyframeTrack(\.lift) {
          LinearKeyframe(0, duration: 0.18)
          SpringKeyframe(height, duration: 0.45, spring: .smooth)
          CubicKeyframe(height * 0.88, duration: 0.35)
          CubicKeyframe(height * 0.96, duration: 0.35)
          CubicKeyframe(height * 0.7, duration: 0.3)
          SpringKeyframe(0, duration: 0.55, spring: .bouncy)
        }
        KeyframeTrack(\.wing) {
          CubicKeyframe(0.2, duration: 0.18)
          CubicKeyframe(1, duration: 0.2)
          CubicKeyframe(0.35, duration: 0.22)
          CubicKeyframe(1, duration: 0.2)
          CubicKeyframe(0.4, duration: 0.24)
          CubicKeyframe(0.9, duration: 0.22)
          CubicKeyframe(0.75, duration: 0.35)
          CubicKeyframe(1, duration: 0.18)
          CubicKeyframe(0, duration: 0.4)
        }
        KeyframeTrack(\.tilt) {
          CubicKeyframe(-3 * direction, duration: 0.18)
          CubicKeyframe(10 * direction, duration: 0.45)
          CubicKeyframe(4 * direction, duration: 0.7)
          CubicKeyframe(-6 * direction, duration: 0.25)
          SpringKeyframe(0, duration: 0.5, spring: .bouncy)
        }
        KeyframeTrack(\.scale) {
          CubicKeyframe(1, duration: 0.18)
          CubicKeyframe(1.05, duration: 0.45)
          CubicKeyframe(1.0, duration: 1.0)
        }
      }
    } else {
      content
    }
  }
}

extension EnvironmentValues {
  @Entry var owlWingSpread: Double = 0
}

/// An owl that feels alive: it breathes, blinks, looks around, and reacts when tapped: a wave, a hop, a wink,
/// a happy flap, a curious head tilt, a startled jump, or a hoot. Long press ruffles his feathers.
/// Unless told otherwise, Dippy sleeps whenever the US market is closed, everywhere in the app.
struct LivelyOwl: View {
  var lookOffset: CGSize = .zero
  var hopsOnTap = true
  /// Nil follows the market clock.
  var mood: OwlMood? = nil
  /// Something Dippy does as he appears, like waving hello.
  var greeting: OwlReaction? = nil
  /// With an ID, the greeting plays once per launch instead of every time the view appears.
  var greetingID: String? = nil
  var greetingDelay = 0.6
  @Environment(\.owlWingSpread) private var wingSpread
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hops = 0
  @State private var taps = 0
  @State private var blink = 0.0
  @State private var look = CGSize.zero
  @State private var stretch = 0.0
  @State private var breathing = false
  @State private var peek = 0.0
  @State private var recentTaps: [Date] = []
  @State private var spin = 0.0
  @State private var bubble: String?
  @State private var ruffle = 0
  @State private var wakeUps = 0
  @State private var isWaking = false
  @State private var leftWing = 0.0
  @State private var rightWing = 0.0
  @State private var eyeScale = 1.0
  @State private var beakOpen = 0.0
  @State private var tilt = 0.0
  @State private var isReacting = false
  @State private var lastReaction: OwlReaction?

  private var effectiveMood: OwlMood {
    if let mood { return mood }
    return MarketClock.isOpen() || OwlWake.shared.isAwake ? .calm : .sleeping
  }

  var body: some View {
    let isAsleep = effectiveMood == .sleeping
    OwlMark(
      wingSpread: max(wingSpread, stretch),
      blink: isAsleep ? 1 : blink,
      lookOffset: lookOffset == .zero ? look : lookOffset,
      rightEyeOpen: peek,
      leftWing: leftWing,
      rightWing: rightWing,
      eyeScale: eyeScale,
      beakOpen: beakOpen
    )
    .scaleEffect(x: 1, y: breathing ? (isAsleep ? 1.04 : 1.025) : 1, anchor: .bottom)
    .rotationEffect(.degrees(tilt), anchor: .bottom)
    .keyframeAnimator(initialValue: 0.0, trigger: ruffle) { view, angle in
      view.rotationEffect(.degrees(angle), anchor: .bottom)
    } keyframes: { _ in
      KeyframeTrack {
        LinearKeyframe(-7, duration: 0.06)
        LinearKeyframe(7, duration: 0.08)
        LinearKeyframe(-5, duration: 0.08)
        LinearKeyframe(4, duration: 0.08)
        SpringKeyframe(0, duration: 0.25, spring: .bouncy)
      }
    }
    .keyframeAnimator(initialValue: WakePose(), trigger: wakeUps) { view, pose in
      view
        .scaleEffect(x: 2 - pose.stretch, y: pose.stretch, anchor: .bottom)
        .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
    } keyframes: { _ in
      // A sleepy shiver, a crouch, then a long, happy stretch upward.
      KeyframeTrack(\.stretch) {
        CubicKeyframe(0.94, duration: 0.18)
        SpringKeyframe(1.1, duration: 0.4, spring: .smooth)
        CubicKeyframe(1.08, duration: 0.35)
        SpringKeyframe(1, duration: 0.5, spring: .bouncy)
      }
      KeyframeTrack(\.tilt) {
        CubicKeyframe(-4, duration: 0.1)
        CubicKeyframe(4, duration: 0.12)
        CubicKeyframe(0, duration: 0.2)
        CubicKeyframe(0, duration: 0.5)
        CubicKeyframe(-5, duration: 0.2)
        SpringKeyframe(0, duration: 0.4, spring: .bouncy)
      }
    }
    .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
    .overlay(alignment: .topTrailing) {
      if isAsleep && peek < 0.5 {
        SleepingZs()
          .offset(x: 14, y: -10)
          .transition(.scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
      }
    }
    .overlay(alignment: .top) {
      if let bubble {
        Text(bubble)
          .font(.caption.weight(.heavy))
          .foregroundStyle(Brand.owlInk)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.white, in: .capsule)
          .fixedSize()
          .offset(y: -22)
          .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
      }
    }
    .contentShape(.rect)
    .onTapGesture { handleTap(isAsleep: isAsleep) }
    .onLongPressGesture(minimumDuration: 0.45) { hoot() }
    .owlFlight(trigger: hops, direction: hops.isMultiple(of: 2) ? 1 : -1, height: 22, isEnabled: !reduceMotion)
    .sensoryFeedback(.impact(weight: .light), trigger: taps)
    .sensoryFeedback(.impact(weight: .medium), trigger: ruffle)
    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: wakeUps)
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathing = true }
    }
    .task {
      guard !reduceMotion else { return }
      if let greeting, effectiveMood != .sleeping, greetingID.map({ !OwlReaction.shownGreetings.contains($0) }) ?? true {
        if let greetingID { OwlReaction.shownGreetings.insert(greetingID) }
        try? await Task.sleep(for: .seconds(greetingDelay))
        await perform(greeting)
      }
      await liveForever()
    }
  }

  private func say(_ text: String, for seconds: Double = 1.4) {
    withAnimation(.bouncy) { bubble = text }
    Task {
      try? await Task.sleep(for: .seconds(seconds))
      withAnimation(.smooth) { if bubble == text { bubble = nil } }
    }
  }

  private func handleTap(isAsleep: Bool) {
    taps += 1
    if isAsleep {
      wakeUp()
      return
    }
    guard !isWaking else { return }
    guard hopsOnTap, !reduceMotion else {
      blinkOnce()
      return
    }
    // Five quick taps: a barrel roll.
    recentTaps = recentTaps.filter { Date.now.timeIntervalSince($0) < 2 } + [.now]
    if recentTaps.count >= 5 {
      recentTaps = []
      withAnimation(.spring(duration: 0.9, bounce: 0.3)) { spin += 360 }
      Task { await perform(.flap) }
      say("Wheee!")
      return
    }
    guard !isReacting else {
      hops += 1
      return
    }
    // Something different each time, never the same twice in a row.
    let next = OwlReaction.onTap.filter { $0 != lastReaction }.randomElement() ?? .hop
    Task { await perform(next) }
  }

  // MARK: Reactions

  /// Plays one reaction from start to finish.
  private func perform(_ reaction: OwlReaction) async {
    guard !isReacting else { return }
    isReacting = true
    lastReaction = reaction
    defer { isReacting = false }
    switch reaction {
    case .wave: await wave()
    case .hop:
      hops += 1
      blinkOnce()
      try? await Task.sleep(for: .seconds(0.6))
    case .wink: await wink()
    case .flap: await flap()
    case .tilt: await tiltHead()
    case .surprise: await startle()
    case .hoot: await hootOut()
    }
  }

  /// Lifts the wing on the right and waves it a few times, leaning in a little.
  private func wave() async {
    say(["Hi!", "Hoo hi!", "Hello!"].randomElement() ?? "Hi!", for: 1.6)
    withAnimation(.snappy(duration: 0.28)) {
      rightWing = 1.05
      tilt = -5
      look = CGSize(width: 0.2, height: -0.2)
    }
    try? await Task.sleep(for: .seconds(0.3))
    for _ in 0..<3 {
      withAnimation(.easeInOut(duration: 0.17)) { rightWing = 0.72 }
      try? await Task.sleep(for: .seconds(0.17))
      withAnimation(.easeInOut(duration: 0.17)) { rightWing = 1.1 }
      try? await Task.sleep(for: .seconds(0.17))
    }
    withAnimation(.smooth(duration: 0.4)) {
      rightWing = 0
      tilt = 0
      look = .zero
    }
    try? await Task.sleep(for: .seconds(0.4))
  }

  private func wink() async {
    withAnimation(.snappy(duration: 0.15)) {
      blink = 1
      peek = 1
      tilt = 6
    }
    try? await Task.sleep(for: .seconds(0.55))
    withAnimation(.snappy(duration: 0.2)) {
      blink = 0
      peek = 0
      tilt = 0
    }
    try? await Task.sleep(for: .seconds(0.2))
  }

  /// Both wings, three quick happy beats, with a hop.
  private func flap() async {
    hops += 1
    for _ in 0..<3 {
      withAnimation(.easeOut(duration: 0.13)) {
        leftWing = 0.85
        rightWing = 0.85
      }
      try? await Task.sleep(for: .seconds(0.13))
      withAnimation(.easeIn(duration: 0.13)) {
        leftWing = 0.25
        rightWing = 0.25
      }
      try? await Task.sleep(for: .seconds(0.13))
    }
    withAnimation(.smooth(duration: 0.3)) {
      leftWing = 0
      rightWing = 0
    }
    try? await Task.sleep(for: .seconds(0.3))
  }

  /// A curious head tilt, the way owls do when something catches their eye.
  private func tiltHead() async {
    let direction: Double = Bool.random() ? 1 : -1
    withAnimation(.spring(duration: 0.4, bounce: 0.35)) {
      tilt = 13 * direction
      look = CGSize(width: -0.6 * direction, height: -0.5)
    }
    say(["Hmm?", "Ooh?"].randomElement() ?? "Hmm?", for: 1.1)
    try? await Task.sleep(for: .seconds(0.95))
    withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
      tilt = 0
      look = .zero
    }
    try? await Task.sleep(for: .seconds(0.4))
  }

  /// Wide eyes and a startled jump.
  private func startle() async {
    withAnimation(.spring(duration: 0.2, bounce: 0.5)) {
      eyeScale = 1.24
      leftWing = 0.35
      rightWing = 0.35
    }
    hops += 1
    say("Oh!", for: 1)
    try? await Task.sleep(for: .seconds(0.55))
    withAnimation(.smooth(duration: 0.45)) {
      eyeScale = 1
      leftWing = 0
      rightWing = 0
    }
    try? await Task.sleep(for: .seconds(0.4))
  }

  /// Two hoots with the beak open, and a ruffle.
  private func hootOut() async {
    ruffle += 1
    say(["Hoo hoo!", "Buy low!", "Patience…"].randomElement() ?? "Hoo!", for: 1.4)
    for _ in 0..<2 {
      withAnimation(.easeOut(duration: 0.12)) { beakOpen = 1 }
      try? await Task.sleep(for: .seconds(0.2))
      withAnimation(.easeIn(duration: 0.14)) { beakOpen = 0 }
      try? await Task.sleep(for: .seconds(0.16))
    }
  }

  /// Waking up: one sleepy eye peeks, then both pop open, a shiver, a big stretch,
  /// a look around, and a happy little hop. He then stays awake until the app is closed.
  private func wakeUp() {
    guard !isWaking else { return }
    isWaking = true
    guard !reduceMotion else {
      OwlWake.shared.wake()
      isWaking = false
      return
    }
    withAnimation(.snappy(duration: 0.25)) { peek = 1 }
    Task {
      try? await Task.sleep(for: .seconds(0.6))
      wakeUps += 1
      OwlWake.shared.wake()
      withAnimation(.snappy(duration: 0.2)) { peek = 0 }
      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.smooth(duration: 0.5)) { stretch = 1 }
      try? await Task.sleep(for: .seconds(0.75))
      withAnimation(.smooth(duration: 0.45)) { stretch = 0 }
      blinkOnce()
      try? await Task.sleep(for: .seconds(0.25))
      blinkOnce()
      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.snappy(duration: 0.3)) { look = CGSize(width: -1, height: -0.2) }
      try? await Task.sleep(for: .seconds(0.45))
      withAnimation(.snappy(duration: 0.3)) { look = CGSize(width: 1, height: -0.2) }
      try? await Task.sleep(for: .seconds(0.45))
      withAnimation(.snappy(duration: 0.3)) { look = .zero }
      try? await Task.sleep(for: .seconds(0.2))
      hops += 1
      isWaking = false
    }
  }

  /// Long press: Dippy hoots and ruffles his feathers.
  private func hoot() {
    if effectiveMood == .sleeping {
      wakeUp()
      return
    }
    withAnimation(.easeOut(duration: 0.2)) { stretch = 0.6 }
    Task {
      try? await Task.sleep(for: .seconds(0.35))
      withAnimation(.easeIn(duration: 0.3)) { stretch = 0 }
      await perform(.hoot)
    }
  }

  private func blinkOnce() {
    withAnimation(.easeIn(duration: 0.07)) { blink = 1 }
    withAnimation(.easeOut(duration: 0.12).delay(0.1)) { blink = 0 }
  }

  /// Small, random idle behaviors, like a real owl on a branch.
  private func liveForever() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(Double.random(in: 1.6...3.8)))
      if effectiveMood == .sleeping || isWaking || isReacting { continue }
      if effectiveMood == .celebrating, Int.random(in: 0..<8) == 0 {
        await perform(Bool.random() ? .flap : .hop)
        continue
      }
      switch Int.random(in: 0..<24) {
      case 0..<9:
        blinkOnce()
      case 9..<11:
        blinkOnce()
        try? await Task.sleep(for: .seconds(0.3))
        blinkOnce()
      case 11..<16:
        let direction = CGSize(width: [-1.0, 1.0].randomElement() ?? 1, height: Double.random(in: -0.4...0.3))
        withAnimation(.snappy(duration: 0.3)) { look = direction }
        try? await Task.sleep(for: .seconds(Double.random(in: 0.9...1.6)))
        withAnimation(.snappy(duration: 0.35)) { look = .zero }
      case 16..<18:
        withAnimation(.easeOut(duration: 0.35)) { stretch = 0.55 }
        try? await Task.sleep(for: .seconds(0.45))
        withAnimation(.easeIn(duration: 0.3)) { stretch = 0 }
      case 20:
        await perform(.tilt)
      case 21 where Int.random(in: 0..<3) == 0:
        await perform(.wave)
      default:
        blinkOnce()
      }
    }
  }
}

/// Squash and tilt for the wake-up stretch.
private struct WakePose {
  var stretch: Double = 1
  var tilt: Double = 0
}

/// Floating "z" letters for a sleeping owl.
private struct SleepingZs: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { timeline in
      let t = timeline.date.timeIntervalSinceReferenceDate
      ZStack {
        ForEach(0..<3) { index in
          let phase = (t / 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
          Text("z")
            .font(.system(size: 9 + CGFloat(index) * 3, weight: .heavy, design: .rounded))
            .foregroundStyle(.secondary.opacity(1 - phase))
            .offset(x: phase * 14, y: -phase * 26)
        }
      }
    }
    .frame(width: 24, height: 30)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
