public enum PlannedAction: Equatable, Sendable {
    case change(from: AppInfo?, to: AppInfo)
    case unchanged(AppInfo)
    case missingApp
}

public struct PlannedChange: Equatable, Sendable {
    public let line: ApplyLine
    public let action: PlannedAction

    public init(line: ApplyLine, action: PlannedAction) {
        self.line = line
        self.action = action
    }
}

public enum ApplyOutcome: Equatable, Sendable {
    case applied
    case unchanged
    case skippedMissingApp
    case failed(String)
}

public struct AppliedChange: Equatable, Sendable {
    public let line: ApplyLine
    public let outcome: ApplyOutcome

    public init(line: ApplyLine, outcome: ApplyOutcome) {
        self.line = line
        self.outcome = outcome
    }
}

/// Unlike duti, applying never stops at a broken line: a fresh machine is
/// missing half its apps, and the point is to apply everything that can be
/// applied and report the rest.
public struct ApplyService: Sendable {
    let registry: any HandlerRegistry
    let writer: any HandlerWriter

    public init(registry: any HandlerRegistry, writer: any HandlerWriter) {
        self.registry = registry
        self.writer = writer
    }

    public func plan(_ spec: ApplySpec) -> [PlannedChange] {
        let query = QueryService(registry: registry)
        return spec.lines.map { line in
            guard let app = registry.application(withBundleID: line.bundleID) else {
                return PlannedChange(line: line, action: .missingApp)
            }
            let current = (try? query.query(line.target))?.defaultApp
            if current?.bundleID == app.bundleID {
                return PlannedChange(line: line, action: .unchanged(app))
            }
            return PlannedChange(line: line, action: .change(from: current, to: app))
        }
    }

    public func apply(_ spec: ApplySpec) async -> [AppliedChange] {
        let set = SetService(registry: registry, writer: writer)
        var results: [AppliedChange] = []
        for planned in plan(spec) {
            let outcome: ApplyOutcome
            switch planned.action {
            case .missingApp:
                outcome = .skippedMissingApp
            case .unchanged:
                outcome = .unchanged
            case .change:
                do {
                    _ = try await set.setDefault(
                        bundleID: planned.line.bundleID, for: planned.line.target)
                    outcome = .applied
                } catch {
                    outcome = .failed(String(describing: error))
                }
            }
            results.append(AppliedChange(line: planned.line, outcome: outcome))
        }
        return results
    }
}
