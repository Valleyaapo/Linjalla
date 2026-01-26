import Foundation

public enum VehicleManagerConstants {
    public static let staleThreshold: TimeInterval = 300 // 5 minutes
    public static let updateInterval: TimeInterval = 1.0
    public static let cleanupInterval: TimeInterval = 5.0
    public static let graphQLEndpoint = "https://api.digitransit.fi/routing/v2/hsl/gtfs/v1"
    public static let mqttReconnectMaxAttempts = 3
    public static let mqttReconnectBaseDelay: TimeInterval = 0.5
    public static let mqttReconnectMaxDelay: TimeInterval = 30.0
}

public enum MapConstants {
    /// Zoom threshold for showing stops (latitude delta)
    public static let showStopsThreshold: Double = 0.05
    /// Zoom threshold for showing stop names (latitude delta)
    public static let showStopNamesThreshold: Double = 0.005
    /// Default map span delta
    public static let defaultSpanDelta: Double = 0.02
    /// Number of departures to fetch
    public static let departuresFetchCount = 10
    /// Number of station departures to fetch (to cover selected lines)
    public static let stationDeparturesFetchCount = 50
    /// Distance for merging nearby stops into a combined departures view
    public static let stopMergeDistanceMeters: Double = 25
    /// Extra distance for merging stops with the same name (opposite directions)
    public static let stopNameMergeDistanceMeters: Double = 70
}
