import AppKit
import ApplicationServices

/// Identity and selection only. Never retains the destination's text or title.
@MainActor
struct InsertionTarget {
    let pid: pid_t
    let window: AXUIElement
    let element: AXUIElement
    let document: AXUIElement?
    let selection: CFRange?
    let role: String
    let subrole: String?
    let enabled: Bool?
    let acceptsSelectedText: Bool
    let bundleIdentifier: String?

    var requiresTerminalEvents: Bool {
        bundleIdentifier == "com.apple.Terminal" && role == kAXTextAreaRole && document == nil
    }

    var acceptsInsertion: Bool {
        guard enabled != false, subrole != kAXSecureTextFieldSubrole else { return false }
        if requiresTerminalEvents {
            // A Terminal selection is display/scrollback text, not a replaceable
            // shell input range. Never imply that dictation replaces it.
            return selection == nil || selection?.length == 0
        }
        return acceptsSelectedText && [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role)
    }

    func matches(_ other: InsertionTarget, checkSelection: Bool) -> Bool {
        guard pid == other.pid, requiresTerminalEvents == other.requiresTerminalEvents, other.acceptsInsertion,
            CFEqual(window, other.window), CFEqual(element, other.element)
        else { return false }
        switch (document, other.document) {
        case (nil, nil): break
        case (let lhs?, let rhs?) where CFEqual(lhs, rhs): break
        default: return false
        }
        guard checkSelection, let selection else { return true }
        return other.selection?.location == selection.location && other.selection?.length == selection.length
    }

    static func read(pid: pid_t) -> InsertionTarget? {
        let app = AXUIElementCreateApplication(pid)
        guard let window = elementAttribute(app, kAXFocusedWindowAttribute),
            let field = elementAttribute(app, kAXFocusedUIElementAttribute),
            belongs(window, to: pid), belongs(field, to: pid),
            let role = attribute(field, kAXRoleAttribute) as? String
        else { return nil }
        var settable = DarwinBoolean(false)
        let status = AXUIElementIsAttributeSettable(field, kAXSelectedTextAttribute as CFString, &settable)
        var selection: CFRange?
        if let value = attribute(field, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
            var range = CFRange()
            if AXValueGetValue(value as! AXValue, .cfRange, &range) { selection = range }
        }
        var ancestor: AXUIElement? = field
        var document: AXUIElement?
        for _ in 0..<64 {
            guard let current = ancestor else { break }
            if attribute(current, kAXRoleAttribute) as? String == "AXWebArea" {
                document = current
                break
            }
            ancestor = elementAttribute(current, kAXParentAttribute)
        }
        return InsertionTarget(
            pid: pid, window: window, element: field, document: document, selection: selection,
            role: role, subrole: attribute(field, kAXSubroleAttribute) as? String,
            enabled: attribute(field, kAXEnabledAttribute) as? Bool,
            acceptsSelectedText: status == .success && settable.boolValue,
            bundleIdentifier: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func belongs(_ element: AXUIElement, to pid: pid_t) -> Bool {
        var actual: pid_t = 0
        return AXUIElementGetPid(element, &actual) == .success && actual == pid
    }
}
