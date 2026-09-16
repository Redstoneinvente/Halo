from pathlib import Path

path = Path("Halo/Views/PixelPetWidget.swift")
s = path.read_text()

if "@State private var cookieLingerStartedAt: Date?" in s:
    print("Cookie tease behavior already present; nothing to patch.")
    raise SystemExit(0)


def once(old: str, new: str, label: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    s = s.replace(old, new, 1)


# Track the beginning of a deliberate cookie tease independently from the
# coarse pointer used by the eye/chase reactions.
once(
    "    @State private var precisePointer = CGPoint.zero\n    @State private var animationEpoch = Date()",
    "    @State private var precisePointer = CGPoint.zero\n    @State private var cookieLingerStartedAt: Date?\n    @State private var animationEpoch = Date()",
    "cookie linger state",
)

# Resolve the cookie hot zone every TimelineView update. The .task below is
# keyed by this Bool, so a perfectly stationary cursor still progresses from
# anticipation -> drool -> reach -> devour.
once(
    "                let expression = resolvedExpression(base: state.expression, date: timeline.date)\n                let side = max(1, min(proxy.size.width, proxy.size.height))",
    "                let expression = resolvedExpression(base: state.expression, date: timeline.date)\n                let side = max(1, min(proxy.size.width, proxy.size.height))\n                let cookieHotzoneActive = isPointerOnCookie(expression: expression, date: timeline.date)",
    "cookie hotzone state",
)

once(
    "                    pointer: pal.preferences.hoverReaction && hovering ? pointer : .zero,\n                    cookiePointer: hovering ? precisePointer : nil,\n                    showAlwaysCookie: pal.preferences.alwaysCookie,",
    "                    pointer: pal.preferences.hoverReaction && hovering ? pointer : .zero,\n                    cookiePointer: hovering ? precisePointer : nil,\n                    cookieLingerElapsed: cookieHotzoneActive ? cookieLingerStartedAt.map { max(0, timeline.date.timeIntervalSince($0)) } : nil,\n                    showAlwaysCookie: pal.preferences.alwaysCookie,",
    "face linger elapsed",
)

once(
    "                .frame(width: side, height: side)\n                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)\n                .onContinuousHover { phase in",
    '''                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .task(id: cookieHotzoneActive) {
                    guard cookieHotzoneActive else {
                        cookieLingerStartedAt = nil
                        return
                    }

                    let started = Date()
                    cookieLingerStartedAt = started
                    try? await Task.sleep(nanoseconds: 2_400_000_000)
                    guard !Task.isCancelled,
                          cookieLingerStartedAt == started,
                          isPointerOnCookie(expression: expression, date: Date()) else { return }

                    cookieLingerStartedAt = nil
                    pal.feedCookie()
                }
                .onContinuousHover { phase in''',
    "cookie tease task",
)

once(
    "                        hovering = false\n                        pointer = .zero\n                        precisePointer = .zero\n                        orbitDetector.resetPath()",
    "                        hovering = false\n                        pointer = .zero\n                        precisePointer = .zero\n                        cookieLingerStartedAt = nil\n                        orbitDetector.resetPath()",
    "hover tease reset",
)

once(
    "            hovering = false\n            pointer = .zero\n            precisePointer = .zero\n            orbitDetector.resetPath()",
    "            hovering = false\n            pointer = .zero\n            precisePointer = .zero\n            cookieLingerStartedAt = nil\n            orbitDetector.resetPath()",
    "disappear tease reset",
)

once(
    "    private func syncAudioSpectrum() {",
    '''    private func isPointerOnCookie(expression: HaloPixelPalExpression, date: Date) -> Bool {
        guard hovering else { return false }

        let target: CGPoint?
        if expression == .furious,
           pal.cookieRescueStarted == nil,
           pal.reaction == .furious {
            let elapsed = date.timeIntervalSince(pal.reactionStarted)
            target = (elapsed >= 1.05 && elapsed < 2.15) ? .zero : nil
        } else if pal.preferences.alwaysCookie,
                  expression != .furious,
                  pal.cookieFeedStarted == nil,
                  pal.cookieSatisfactionStarted == nil {
            target = CGPoint(x: 0.64, y: 0.64)
        } else {
            target = nil
        }

        guard let target else { return false }
        let dx = Double(precisePointer.x - target.x)
        let dy = Double(precisePointer.y - target.y)
        return hypot(dx, dy) <= 0.20
    }

    private func syncAudioSpectrum() {''',
    "cookie hotzone helper",
)

# Give the face renderer the elapsed linger time so it can escalate visually.
once(
    "    var pointer: CGPoint = .zero\n    var cookiePointer: CGPoint? = nil\n    var showAlwaysCookie = true",
    "    var pointer: CGPoint = .zero\n    var cookiePointer: CGPoint? = nil\n    var cookieLingerElapsed: TimeInterval? = nil\n    var showAlwaysCookie = true",
    "face linger property",
)

once(
    "    private var isCookieAnticipating: Bool {\n        !isEatingAnyCookie && cookieApproachIntensity > 0.035\n    }\n\n    private var faceColor: Color {",
    '''    private var isCookieAnticipating: Bool {
        !isEatingAnyCookie && cookieApproachIntensity > 0.035
    }

    private var cookieTeaseElapsed: TimeInterval {
        max(0, cookieLingerElapsed ?? 0)
    }

    private var isCookieDrooling: Bool {
        !isEatingAnyCookie && cookieLingerElapsed != nil && cookieTeaseElapsed >= 0.90
    }

    private var isCookieReaching: Bool {
        !isEatingAnyCookie && cookieLingerElapsed != nil && cookieTeaseElapsed >= 1.65
    }

    private var cookieReachProgress: Double {
        min(1.0, max(0.0, (cookieTeaseElapsed - 1.65) / 0.75))
    }

    private var faceColor: Color {''',
    "cookie tease face helpers",
)

# Drool uses the existing tiny tear sprite, positioned at the mouth. During the
# final reach phase the pet gets extra sparkle urgency before it steals the food.
once(
    "        let phase = reduceMotion || preferences.animationIntensity == 0 ? 0 : Int(max(0, animationTime) * max(0.35, preferences.animationSpeed) * 4) % 4\n        let lift = -(phase / 2)\n        if isCookieAnticipating && cookieApproachIntensity >= 0.72 {",
    '''        let phase = reduceMotion || preferences.animationIntensity == 0 ? 0 : Int(max(0, animationTime) * max(0.35, preferences.animationSpeed) * 4) % 4
        let lift = -(phase / 2)
        if isCookieDrooling {
            let drip = reduceMotion ? 0 : Int((cookieTeaseElapsed * 4.0).truncatingRemainder(dividingBy: 3.0))
            render(.init(HaloPixelPalSprites.tear, x: 13, y: 18), 0.96, 0, drip)
            if isCookieReaching {
                render(.init(HaloPixelPalSprites.sparkle, x: 1, y: 3), 0.92, 0, lift)
                render(.init(HaloPixelPalSprites.sparkle, x: 20, y: 2), 0.82, 0, -lift)
            }
            return
        }
        if isCookieAnticipating && cookieApproachIntensity >= 0.72 {''',
    "drool and reach fx",
)

# Once the tease passes the reach threshold, lunge the entire authored face
# toward the cookie while retaining a tiny impatient tremble. At 2.4s the task
# above calls the normal feedCookie() path, which supplies the existing chew and
# satisfied animations.
once(
    "        let one = intensity > 0.28 ? 1 : 0\n        let two = intensity > 0.75 ? 2 : one\n        if isCookieAnticipating {",
    '''        let one = intensity > 0.28 ? 1 : 0
        let two = intensity > 0.75 ? 2 : one
        if isCookieReaching {
            let target = cookieTargetCenter ?? .zero
            let reach = Int(round(cookieReachProgress * Double(max(1, two))))
            let xDirection = target.x > 0.08 ? 1 : (target.x < -0.08 ? -1 : 0)
            let yDirection = target.y > 0.08 ? 1 : (target.y < -0.08 ? -1 : 0)
            let tremble = Int(round(sin(t * 14.0))) * one
            return (xDirection * reach + tremble, yDirection * reach)
        }
        if isCookieAnticipating {''',
    "cookie reach motion",
)

path.write_text(s)
print("Pixel Pet cookie tease, drool, reach, and auto-devour behavior added.")
