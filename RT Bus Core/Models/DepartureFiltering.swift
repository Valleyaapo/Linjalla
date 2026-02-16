import Foundation

public struct DepartureFilterInput: Sendable {
    public let routeIds: Set<String>
    public let lineNames: Set<String>
    public let includePast: Bool

    // Optimized set for O(1) lookups of line names and their base variants
    fileprivate let matchingLineNames: Set<String>

    public init(routeIds: Set<String>, lineNames: Set<String>, includePast: Bool) {
        self.routeIds = routeIds
        self.lineNames = lineNames
        self.includePast = includePast

        var matches = lineNames
        for id in routeIds {
            var s = id
            if s.hasPrefix("HSL:") {
                s = String(s.dropFirst(4))
            }
            matches.insert(s)

            if s.hasSuffix("N") || s.hasSuffix("B") || s.hasSuffix("K") {
                matches.insert(String(s.dropLast()))
            }
        }
        self.matchingLineNames = matches
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
        // 1. Exact routeId match (fastest)
        if let routeId = departure.routeId {
            if filter.routeIds.contains(routeId) {
                return true
            }

            // 2. Normalized routeId check
            // Use substring slicing to avoid full string replacement if possible
            let normalized = routeId.hasPrefix("HSL:") ? String(routeId.dropFirst(4)) : routeId
            if filter.matchingLineNames.contains(normalized) {
                return true
            }
        }

        // 3. Line name check
        // This covers exact line name matches AND base variant matches
        // because matchingLineNames includes base names derived from filter routeIds.
        return filter.matchingLineNames.contains(departure.lineName)
    }

    private static func departureTimestamp(_ departure: Departure) -> TimeInterval {
        TimeInterval(departure.serviceDay + departure.realtimeTime)
    }
}
