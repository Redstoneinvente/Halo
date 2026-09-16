from pathlib import Path

path = Path("Halo/NotchEngine/DisplayClock.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    text = text.replace(old, new, 1)


helper_anchor = "@MainActor\nprivate final class HaloEmbeddedDropZoneController {"
helper = '''private var haloDropCIEnabled: Bool {
    let defaults = UserDefaults.standard
    return defaults.object(forKey: "HaloContextDropEnabled") == nil
        ? true
        : defaults.bool(forKey: "HaloContextDropEnabled")
}

@MainActor
private final class HaloEmbeddedDropZoneController {'''
if "private var haloDropCIEnabled: Bool" not in text:
    replace_once(helper_anchor, helper, "insert shared Drop CI enabled helper")

begin_old = '''    func begin(target: any HaloGlobalDropTarget, itemCount: Int) {
        dropHandled = false
'''
begin_new = '''    func begin(target: any HaloGlobalDropTarget, itemCount: Int) {
        guard haloDropCIEnabled else {
            target.dragStateHandler?(false, 0)
            dismiss()
            return
        }
        dropHandled = false
'''
if "guard haloDropCIEnabled else {\n            target.dragStateHandler?(false, 0)" not in text:
    replace_once(begin_old, begin_new, "guard embedded Drop CI presentation")

handle_old = '''    private func handleMouseEvent(_ type: NSEvent.EventType) {
        switch type {
'''
handle_new = '''    private func handleMouseEvent(_ type: NSEvent.EventType) {
        guard haloDropCIEnabled else {
            deactivateForDisabledState()
            return
        }
        switch type {
'''
if "private func handleMouseEvent(_ type: NSEvent.EventType) {\n        guard haloDropCIEnabled" not in text:
    replace_once(handle_old, handle_new, "guard global mouse event path")

poll_old = '''    private func pollDragSession() {
        let leftButtonDown = (NSEvent.pressedMouseButtons & 1) != 0
'''
poll_new = '''    private func pollDragSession() {
        guard haloDropCIEnabled else {
            deactivateForDisabledState()
            return
        }
        let leftButtonDown = (NSEvent.pressedMouseButtons & 1) != 0
'''
if "private func pollDragSession() {\n        guard haloDropCIEnabled" not in text:
    replace_once(poll_old, poll_new, "guard global drag polling path")

inspect_old = '''    private func inspectDragPasteboard() {
        let pasteboard = NSPasteboard(name: .drag)
'''
inspect_new = '''    private func inspectDragPasteboard() {
        guard haloDropCIEnabled else {
            deactivateForDisabledState()
            return
        }
        let pasteboard = NSPasteboard(name: .drag)
'''
if "private func inspectDragPasteboard() {\n        guard haloDropCIEnabled" not in text:
    replace_once(inspect_old, inspect_new, "guard drag pasteboard path")

activate_old = '''    private func activateTarget(at point: NSPoint, count: Int) {
        guard let target = targetForDrag(at: point) else { return }
'''
activate_new = '''    private func activateTarget(at point: NSPoint, count: Int) {
        guard haloDropCIEnabled else {
            deactivateForDisabledState()
            return
        }
        guard let target = targetForDrag(at: point) else { return }
'''
if "private func activateTarget(at point: NSPoint, count: Int) {\n        guard haloDropCIEnabled" not in text:
    replace_once(activate_old, activate_new, "guard final global activation choke point")

deactivate_anchor = '''    private func resetSessionState() {
        activeTarget = nil
'''
deactivate_new = '''    private func deactivateForDisabledState() {
        deferredFinishPending = false
        activeTarget?.dragStateHandler?(false, 0)
        HaloEmbeddedDropZoneController.shared.dismiss()
        resetSessionState()
    }

    private func resetSessionState() {
        activeTarget = nil
'''
if "private func deactivateForDisabledState()" not in text:
    replace_once(deactivate_anchor, deactivate_new, "add global disable cleanup")

path.write_text(text)
print("Guarded all global Drop CI presentation paths behind HaloContextDropEnabled")
