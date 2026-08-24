public enum QueryTarget: Equatable, Sendable {
    case fileExtension(String)
    case contentType(String)
    case scheme(String)

    public var displayString: String {
        switch self {
        case .fileExtension(let ext): ".\(ext)"
        case .contentType(let uti): uti
        case .scheme(let scheme): "\(scheme):"
        }
    }

    /// Classifies a raw command-line argument.
    ///
    /// - trailing `:` → scheme (`mailto:`)
    /// - leading `.` → file extension (`.md`)
    /// - contains `.` → UTI (`public.html`)
    /// - otherwise → file extension (`md`)
    public static func parse(_ raw: String) -> QueryTarget? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix(":") {
            let scheme = String(trimmed.dropLast())
            return scheme.isEmpty ? nil : .scheme(scheme.lowercased())
        }
        if trimmed.hasPrefix(".") {
            let ext = String(trimmed.dropFirst())
            return ext.isEmpty ? nil : .fileExtension(ext)
        }
        if trimmed.isEmpty { return nil }
        return trimmed.contains(".") ? .contentType(trimmed) : .fileExtension(trimmed)
    }
}

extension QueryTarget: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, value
    }

    private enum Kind: String, Codable {
        case `extension`, uti, scheme
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(String.self, forKey: .value)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .extension: self = .fileExtension(value)
        case .uti: self = .contentType(value)
        case .scheme: self = .scheme(value)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let (kind, value): (Kind, String) = switch self {
        case .fileExtension(let v): (.extension, v)
        case .contentType(let v): (.uti, v)
        case .scheme(let v): (.scheme, v)
        }
        try container.encode(kind, forKey: .kind)
        try container.encode(value, forKey: .value)
    }
}
