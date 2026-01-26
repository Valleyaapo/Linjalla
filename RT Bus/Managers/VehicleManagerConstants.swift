import Foundation

enum VehicleManagerConstants {
    static let staleThreshold: TimeInterval = 300 // 5 minutes
    static let updateInterval: TimeInterval = 1.0
    static let cleanupInterval: TimeInterval = 5.0
    static let graphQLEndpoint = "https://api.digitransit.fi/routing/v2/hsl/gtfs/v1"
    static let mqttReconnectMaxAttempts = 3
    static let mqttReconnectBaseDelay: TimeInterval = 0.5
    static let mqttReconnectMaxDelay: TimeInterval = 30.0
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
    /// Number of station departures to fetch (to cover selected lines)
    static let stationDeparturesFetchCount = 50
    /// Distance for merging nearby stops into a combined departures view
    static let stopMergeDistanceMeters: Double = 25
    /// Extra distance for merging stops with the same name (opposite directions)
    static let stopNameMergeDistanceMeters: Double = 70
}
