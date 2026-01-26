import Foundation

public struct DepartureFilterInput: Sendable {
    public let routeIds: Set<String>
    public let lineNames: Set<String>
    public let includePast: Bool

    public init(routeIds: Set<String>, lineNames: Set<String>, includePast: Bool) {
        self.routeIds = routeIds
        self.lineNames = lineNames
        self.includePast = includePast
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
            if filter.routeIds.contains(routeId) {
                return true
            }
            let normalized = routeId.replacingOccurrences(of: "HSL:", with: "")
            if filter.lineNames.contains(normalized) {
                return true
            }
        }

        if filter.lineNames.contains(departure.lineName) {
            return true
        }

        let base = "HSL:\(departure.lineName)"
        if filter.routeIds.contains(base) ||
            filter.routeIds.contains(base + "N") ||
            filter.routeIds.contains(base + "B") ||
            filter.routeIds.contains(base + "K") {
            return true
        }

        return false
    }

    private static func departureTimestamp(_ departure: Departure) -> TimeInterval {
        TimeInterval(departure.serviceDay + departure.realtimeTime)
    }
}
