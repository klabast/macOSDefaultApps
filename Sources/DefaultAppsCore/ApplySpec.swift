import Foundation

/// Declarative settings file, duti-compatible:
///
///     # comment
///     com.apple.Safari    public.html    all      # 3 fields: bundle, uti/ext, role
///     com.apple.Finder    ftp                     # 2 fields: bundle, scheme
///
/// The role column exists only for duti compatibility and is ignored —
/// the modern API has no role concept; it always sets the all-roles default.
public struct ApplyLine: Equatable, Sendable {
    public let bundleID: String
    public let target: QueryTarget

    public init(bundleID: String, target: QueryTarget) {
        self.bundleID = bundleID
        self.target = target
    }
}

public enum ApplyParseError: Error, Equatable, CustomStringConvertible {
    case badLine(number: Int, content: String)

    public var description: String {
        switch self {
        case .badLine(let number, let content): "bad settings line \(number): '\(content)'"
        }
    }
}

public struct ApplySpec: Equatable, Sendable {
    public let lines: [ApplyLine]

    static let dutiRoles: Set<String> = ["all", "viewer", "editor", "shell", "none"]

    public static func parse(_ text: String) throws -> ApplySpec {
        var lines: [ApplyLine] = []
        let rawLines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        for (index, rawLine) in rawLines.enumerated() {
            let content = rawLine.prefix(while: { $0 != "#" }).trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { continue }
            let fields = content.split(whereSeparator: \.isWhitespace).map(String.init)
            let badLine = ApplyParseError.badLine(number: index + 1, content: content)

            let target: QueryTarget?
            switch fields.count {
            case 2 where !fields[1].contains(".") && !fields[1].contains(":"):
                target = .scheme(fields[1].lowercased())  // duti: two bare fields = scheme
            case 2:
                target = QueryTarget.parse(fields[1])
            case 3 where dutiRoles.contains(fields[2].lowercased()):
                target = QueryTarget.parse(fields[1])
            default:
                throw badLine
            }
            guard let target else { throw badLine }
            lines.append(ApplyLine(bundleID: fields[0], target: target))
        }
        return ApplySpec(lines: lines)
    }

    init(lines: [ApplyLine]) {
        self.lines = lines
    }
}
