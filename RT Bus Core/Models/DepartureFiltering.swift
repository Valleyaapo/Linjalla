import Foundation

public struct DepartureFilterInput: Sendable {
    public let routeIds: Set<String>
    public let lineNames: Set<String>
    public let includePast: Bool

    // Performance Optimization: Cached sets for faster lookups in high-frequency filtering loops
    fileprivate let matchingLineNames: Set<String>
    fileprivate let prefixedLineNames: Set<String>

    public init(routeIds: Set<String>, lineNames: Set<String>, includePast: Bool) {
        self.routeIds = routeIds
        self.lineNames = lineNames
        self.includePast = includePast

        // Pre-calculate matching line names from route IDs to avoid repeated string manipulation in loops
        var matching = Set<String>()
        for id in routeIds {
            if id.hasPrefix("HSL:") {
                let base = String(id.dropFirst(4))
                matching.insert(base)
                // If base ends with a variant suffix (N, B, K), also match the core line number
                // e.g., "HSL:550B" matches lineName "550"
                if let last = base.last, "NBK".contains(last) {
                    matching.insert(String(base.dropLast()))
                }
            }
        }
        self.matchingLineNames = matching

        // Pre-calculate prefixed line names for faster normalization checks
        self.prefixedLineNames = Set(lineNames.map { "HSL:" + $0 })
    }

    public var isEmpty: Bool {
        routeIds.isEmpty && lineNames.isEmpty
    }

    public static func from(_ selectedLines: Set<BusLine>?) -> DepartureFilterInput? {
        guard let selectedLines else { return nil }
        let routeIds = Set(selectedLines.map { $0.id })
        let lineNames = Set(selectedLines.map { $0.shortName })
        return DepartureFilterInput(routeIds: routeIds, lineNames: lineNames, includePast: false)
    }
}

enum DepartureFiltering {
    static func apply(
        _ departures: [Departure],
        filter: DepartureFilterInput?,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> [Departure] {
        var result = departures

        if filter?.includePast != true {
            result = result.filter { departureTimestamp($0) > now }
        }

        if let filter, !filter.isEmpty {
            result = result.filter { matches($0, filter: filter) }
        }

        result.sort { departureTimestamp($0) < departureTimestamp($1) }
        return result
    }

    private static func matches(_ departure: Departure, filter: DepartureFilterInput) -> Bool {
        if let routeId = departure.routeId {
            // Check 1: Exact routeId match
            if filter.routeIds.contains(routeId) {
                return true
            }

            // Check 2: Normalized routeId match (optimized)
            // If routeId starts with "HSL:", check against pre-calculated prefixed set
            // Otherwise check against lineNames directly
            if routeId.hasPrefix("HSL:") {
                if filter.prefixedLineNames.contains(routeId) {
                    return true
                }
            } else if filter.lineNames.contains(routeId) {
                return true
            }
        }

        // Check 3: Departure lineName match
        if filter.lineNames.contains(departure.lineName) {
            return true
        }

        // Check 4: Base + suffix logic (optimized)
        // Uses pre-calculated set to avoid string concatenation and multiple lookups
        if filter.matchingLineNames.contains(departure.lineName) {
            return true
        }

        return false
    }

    private static func departureTimestamp(_ departure: Departure) -> TimeInterval {
        TimeInterval(departure.serviceDay + departure.realtimeTime)
    }
}
