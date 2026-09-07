import Foundation

/// Curated list of type families shown by `mda dump` and the UI.
/// Data rather than code: `Resources/catalog.json`, easy to extend.
/// This is the curated front page, not the full set — `TypeDiscovery`
/// finds the rest and `extended(with:)` appends it.
public struct Catalog: Equatable, Sendable, Decodable {
    public let families: [TypeFamily]

    public init(families: [TypeFamily]) {
        self.families = families
    }

    public static func load(from data: Data) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: data)
    }

    public static func bundled() throws -> Catalog {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogError.missingResource
        }
        return try load(from: Data(contentsOf: url))
    }
}

public enum CatalogError: Error, Equatable, CustomStringConvertible {
    case missingResource

    public var description: String {
        switch self {
        case .missingResource: "bundled catalog.json is missing — broken build"
        }
    }
}

public struct TypeFamily: Equatable, Sendable, Decodable {
    public let name: String
    public let extensions: [String]
    public let utis: [String]
    public let schemes: [String]

    public init(name: String, extensions: [String] = [], utis: [String] = [], schemes: [String] = []) {
        self.name = name
        self.extensions = extensions
        self.utis = utis
        self.schemes = schemes
    }

    enum CodingKeys: String, CodingKey {
        case name, extensions, utis, schemes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        extensions = try container.decodeIfPresent([String].self, forKey: .extensions) ?? []
        utis = try container.decodeIfPresent([String].self, forKey: .utis) ?? []
        schemes = try container.decodeIfPresent([String].self, forKey: .schemes) ?? []
    }

    /// Query targets in declaration order: extensions, then utis, then schemes.
    public var targets: [QueryTarget] {
        extensions.map(QueryTarget.fileExtension)
            + utis.map(QueryTarget.contentType)
            + schemes.map(QueryTarget.scheme)
    }
}
