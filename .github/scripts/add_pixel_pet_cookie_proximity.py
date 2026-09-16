from pathlib import Path

path = Path("Halo/Views/PixelPetWidget.swift")
s = path.read_text()


def once(old: str, new: str, label: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    s = s.replace(old, new, 1)


# Keep the existing coarse pointer for eye/chase gestures, but retain a precise
# normalized pointer for measuring distance to the visible cookie.
once(
    "    @State private var pointer = CGPoint.zero\n    @State private var animationEpoch = Date()",
    "    @State private var pointer = CGPoint.zero\n    @State private var precisePointer = CGPoint.zero\n    @State private var animationEpoch = Date()",
    "precise pointer state",
)

once(
    "                    pointer: pal.preferences.hoverReaction && hovering ? pointer : .zero,\n                    showAlwaysCookie: pal.preferences.alwaysCookie,",
    "                    pointer: pal.preferences.hoverReaction && hovering ? pointer : .zero,\n                    cookiePointer: hovering ? precisePointer : nil,\n                    showAlwaysCookie: pal.preferences.alwaysCookie,",
    "face cookie pointer",
)

once(
    "                        let next = CGPoint(\n                            x: ((location.x / max(1, side) - 0.5) * 2).rounded(),\n                            y: ((location.y / max(1, side) - 0.5) * 2).rounded()\n                        )\n                        if pointer != next { pointer = next }",
    "                        let precise = CGPoint(\n                            x: (location.x / max(1, side) - 0.5) * 2,\n                            y: (location.y / max(1, side) - 0.5) * 2\n                        )\n                        if precisePointer != precise { precisePointer = precise }\n                        let next = CGPoint(x: precise.x.rounded(), y: precise.y.rounded())\n                        if pointer != next { pointer = next }",
    "continuous precise pointer",
)

# Two reset sites: hover end and view disappearance.
reset_old = "                        hovering = false\n                        pointer = .zero\n                        orbitDetector.resetPath()"
reset_new = "                        hovering = false\n                        pointer = .zero\n                        precisePointer = .zero\n                        orbitDetector.resetPath()"
if s.count(reset_old) != 1:
    raise SystemExit(f"hover reset: expected 1 match, found {s.count(reset_old)}")
s = s.replace(reset_old, reset_new, 1)

reset_old = "            hovering = false\n            pointer = .zero\n            orbitDetector.resetPath()"
reset_new = "            hovering = false\n            pointer = .zero\n            precisePointer = .zero\n            orbitDetector.resetPath()"
if s.count(reset_old) != 1:
    raise SystemExit(f"disappear reset: expected 1 match, found {s.count(reset_old)}")
s = s.replace(reset_old, reset_new, 1)

once(
    "    var audioEnergy: Double = 0\n    var pointer: CGPoint = .zero\n    var showAlwaysCookie = true",
    "    var audioEnergy: Double = 0\n    var pointer: CGPoint = .zero\n    var cookiePointer: CGPoint? = nil\n    var showAlwaysCookie = true",
    "face cookie pointer property",
)

once(
    "    private var isCookieSatisfied: Bool {\n        expression == .satisfied || cookieSatisfactionElapsed != nil\n    }\n\n    private var faceColor: Color {",
    '''    private var isCookieSatisfied: Bool {
        expression == .satisfied || cookieSatisfactionElapsed != nil
    }

    /// Cookie positions use the same -1...1 normalized coordinate space as the
    /// pointer. The normal snack lives at 82%/82% of the face; the fury rescue
    /// cookie is centered behind the shutter.
    private var cookieTargetCenter: CGPoint? {
        if expression == .furious,
           cookieRescueElapsed == nil,
           let reactionElapsed,
           reactionElapsed >= 1.05,
           reactionElapsed < 2.15,
           onCookieTap != nil {
            return .zero
        }
        if showAlwaysCookie,
           expression != .furious,
           !isEatingSnackCookie,
           !isCookieSatisfied,
           onCookieTap != nil {
            return CGPoint(x: 0.64, y: 0.64)
        }
        return nil
    }

    /// Smooth 0...1 anticipation value. It begins before the cursor reaches the
    /// cookie hit target, so the pet visibly notices food approaching.
    private var cookieApproachIntensity: Double {
        guard let cursor = cookiePointer, let target = cookieTargetCenter else { return 0 }
        let dx = Double(cursor.x - target.x)
        let dy = Double(cursor.y - target.y)
        let distance = hypot(dx, dy)
        let outerRadius = expression == .furious ? 0.78 : 0.72
        let innerRadius = 0.10
        let linear = min(1.0, max(0.0, (outerRadius - distance) / (outerRadius - innerRadius)))
        return linear * linear * (3.0 - 2.0 * linear)
    }

    private var isCookieAnticipating: Bool {
        !isEatingAnyCookie && cookieApproachIntensity > 0.035
    }

    private var faceColor: Color {''',
    "cookie proximity helpers",
)

once(
    "    private enum EyePose { case open, happy, closed, heart, star, winkLeft, winkRight, confused, dizzy, cookieMunch, furious, smug }\n\n    private var eyePose: EyePose {\n        if isEatingAnyCookie { return .cookieMunch }",
    "    private enum EyePose { case open, happy, closed, heart, star, winkLeft, winkRight, confused, dizzy, cookieAnticipation, cookieMunch, furious, smug }\n\n    private var eyePose: EyePose {\n        if isEatingAnyCookie { return .cookieMunch }\n        if isCookieAnticipating { return .cookieAnticipation }",
    "anticipation eye pose",
)

once(
    "        case .cookieMunch:\n            let happy = HaloPixelPalSprites.happyEye(preferences.eyeStyle)",
    '''        case .cookieAnticipation:
            let happy = HaloPixelPalSprites.happyEye(preferences.eyeStyle)
            if cookieApproachIntensity >= 0.62 {
                let star = HaloPixelPalSprites.starEye
                render(.init(star, x: leftX, y: y), 1, 0, 0)
                render(.init(star, x: rightX, y: y, mirrorX: true), 1, 0, 0)
            } else {
                render(.init(happy, x: leftX, y: y + 1), 1, 0, 0)
                render(.init(happy, x: rightX, y: y + 1, mirrorX: true), 1, 0, 0)
            }
        case .cookieMunch:
            let happy = HaloPixelPalSprites.happyEye(preferences.eyeStyle)''',
    "anticipation eyes",
)

once(
    "    private func drawBrows(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {\n        if isEatingAnyCookie || isCookieSatisfied { return }\n        let leftX = 3",
    '''    private func drawBrows(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        if isEatingAnyCookie || isCookieSatisfied { return }
        let leftX = 3
        if isCookieAnticipating {
            if cookieApproachIntensity < 0.62 {
                render(.init(HaloPixelPalSprites.raisedBrow, x: leftX, y: 3), 0.94, 0, 0)
                render(.init(HaloPixelPalSprites.raisedBrow, x: 16, y: 3, mirrorX: true), 0.94, 0, 0)
            }
            return
        }''',
    "anticipation brows",
)

once(
    "    if isEatingAnyCookie {\n        let chewPhase = Int(cookieChewElapsed * (cookieFeedOrdinal == 2 ? 18.0 : 14.0)) % 2\n        mouth = chewPhase == 0 ? HaloPixelPalSprites.mouthOpen : HaloPixelPalSprites.mouthTiny\n    } else {\n        mouth = selectedMouth()\n    }",
    '''    if isEatingAnyCookie {
        let chewPhase = Int(cookieChewElapsed * (cookieFeedOrdinal == 2 ? 18.0 : 14.0)) % 2
        mouth = chewPhase == 0 ? HaloPixelPalSprites.mouthOpen : HaloPixelPalSprites.mouthTiny
    } else if isCookieAnticipating {
        mouth = cookieApproachIntensity >= 0.62 ? HaloPixelPalSprites.mouthOpen : HaloPixelPalSprites.mouthBigSmile
    } else {
        mouth = selectedMouth()
    }''',
    "anticipation mouth",
)

once(
    "    let y = isEatingAnyCookie ? 15 : (expression == .superHappy || expression == .excited ? 15 : 16)",
    "    let y = (isEatingAnyCookie || isCookieAnticipating) ? 15 : (expression == .superHappy || expression == .excited ? 15 : 16)",
    "anticipation mouth height",
)

once(
    "    if isEatingAnyCookie || isCookieSatisfied {\n        sprite = HaloPixelPalSprites.cheekKawaii",
    "    if isEatingAnyCookie || isCookieSatisfied || isCookieAnticipating {\n        sprite = HaloPixelPalSprites.cheekKawaii",
    "anticipation cheeks sprite",
)

once(
    "    let opacity: Double = isEatingAnyCookie || isCookieSatisfied || expression == .shy || expression == .love || expression == .petting ? 1.0 : 0.90",
    "    let opacity: Double = isEatingAnyCookie || isCookieSatisfied || isCookieAnticipating || expression == .shy || expression == .love || expression == .petting ? 1.0 : 0.90",
    "anticipation cheek opacity",
)

once(
    "    private func drawFX(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {\n        if isEatingAnyCookie { return }\n        let phase =",
    '''    private func drawFX(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        if isEatingAnyCookie { return }
        let phase =''',
    "fx anchor",
)

# Add a tiny sparkle payoff only when the cursor is very close. This is drawn
# before contextual FX so it does not depend on the pet's current base mood.
once(
    "        let lift = -(phase / 2)\n        switch fx {",
    '''        let lift = -(phase / 2)
        if isCookieAnticipating && cookieApproachIntensity >= 0.72 {
            render(.init(HaloPixelPalSprites.sparkle, x: 1, y: 3), 0.82, 0, lift)
            render(.init(HaloPixelPalSprites.sparkle, x: 20, y: 2), 0.72, 0, -lift)
            return
        }
        switch fx {''',
    "anticipation sparkles",
)

once(
    "        let one = intensity > 0.28 ? 1 : 0\n        let two = intensity > 0.75 ? 2 : one\n        if let reactionElapsed {",
    '''        let one = intensity > 0.28 ? 1 : 0
        let two = intensity > 0.75 ? 2 : one
        if isCookieAnticipating {
            let eagerness = cookieApproachIntensity
            let hopRate = 5.0 + eagerness * 4.5
            let hop = Int(round(sin(t * hopRate))) < 0 ? -one : 0
            let wiggle = eagerness >= 0.70 ? Int(round(sin(t * 8.5))) * one : 0
            return (wiggle, hop)
        }
        if let reactionElapsed {''',
    "anticipation motion",
)

path.write_text(s)
print("Pixel Pet cookie proximity expression added.")
