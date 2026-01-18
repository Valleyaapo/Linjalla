import Foundation

enum VehicleManagerConstants {
    static let staleThreshold: TimeInterval = 300 // 5 minutes
    static let updateInterval: TimeInterval = 1.0
    static let cleanupInterval: TimeInterval = 5.0
    static let graphQLEndpoint = "https://api.digitransit.fi/routing/v2/hsl/gtfs/v1"
}

enum MapConstants {
    /// Zoom threshold for showing stops (latitude delta)
    static let showStopsThreshold: Double = 0.05
    /// Zoom threshold for showing stop names (latitude delta)
    static let showStopNamesThreshold: Double = 0.005
    /// Default map span delta
    static let defaultSpanDelta: Double = 0.02
    /// Number of departures to fetch
    static let departuresFetchCount = 10
}
