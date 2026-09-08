/// Single source of truth for the shipped version. `mda --version`, the app's
/// Info.plist and the release workflow all read this one string; CI fails the
/// release if the tag disagrees with it.
public enum Version {
    public static let current = "0.7.1"
}

extension Version {
    /// Numeric per component, so 0.10.0 beats 0.9.9; a leading `v` is fine.
    /// Anything unparsable is never newer.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let candidate = components(candidate), let current = components(current) else {
            return false
        }
        return current.lexicographicallyPrecedes(candidate)
    }

    private static func components(_ version: String) -> [Int]? {
        let digits = version.hasPrefix("v") ? version.dropFirst() : version[...]
        let parts = digits.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.compactMap { $0 }
    }
}
