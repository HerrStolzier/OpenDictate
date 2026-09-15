/// Explicit panel actions may return only to the most recently used target.
public enum PanelTargetPolicy {
    public static func canReturnFocus(target: Int32?, latestExternal: Int32?) -> Bool {
        guard let target, let latestExternal else { return false }
        return target == latestExternal
    }
}
