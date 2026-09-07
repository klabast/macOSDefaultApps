/// Single source of truth for the shipped version. `mda --version`, the app's
/// Info.plist and the release workflow all read this one string; CI fails the
/// release if the tag disagrees with it.
public enum Version {
    public static let current = "0.5.0"
}
