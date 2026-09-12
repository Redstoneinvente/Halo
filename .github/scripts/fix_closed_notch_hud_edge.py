from pathlib import Path

p = Path('Halo/Views/ClosedNotchView.swift')
s = p.read_text()
old = '''    private var showPowerEvent: Bool { powerTargetSide == side }
    private var powerSettings: PowerReactionOptions { options.powerReaction ?? PowerReactionOptions() }
    private var powerNotchMargin: Double { powerSettings.resolvedNotchMargin }
'''
new = '''    private var showPowerEvent: Bool { powerTargetSide == side }
    private var rendersPowerEvent: Bool { showPowerEvent && hudCollision != .replace }
    private var powerSettings: PowerReactionOptions { options.powerReaction ?? PowerReactionOptions() }
    private var powerNotchMargin: Double { powerSettings.resolvedNotchMargin }
'''
if old not in s: raise SystemExit('missing showPowerEvent block')
s = s.replace(old, new, 1)
s = s.replace('layoutMetrics.cameraInset(power: showPowerEvent ? powerSettings : nil)', 'layoutMetrics.cameraInset(power: rendersPowerEvent ? powerSettings : nil)', 1)
s = s.replace('guard showPowerEvent else { return false }\n        return powerSettings.expandForEvent', 'guard rendersPowerEvent else { return false }\n        return powerSettings.expandForEvent', 1)
s = s.replace('guard showPowerEvent else { return 0 }\n        let natural', 'guard rendersPowerEvent else { return 0 }\n        let natural', 1)
s = s.replace('if showPowerEvent, let powerEvent {', 'if rendersPowerEvent, let powerEvent {', 1)
p.write_text(s)
print('HUD replacement now owns its camera edge cleanly')
