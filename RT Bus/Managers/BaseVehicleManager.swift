//
//  BaseVehicleManager.swift
//  RT Bus
//
//  Created by Assistant on 03.01.2026.
//

import Foundation
import SwiftUI
import MQTTNIO
import Combine
import NIO
import NIOFoundationCompat
import NIOTransportServices
import CoreLocation
import Observation
import OSLog

// MARK: - Constants

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

// MARK: - Base Vehicle Manager

@MainActor
@Observable
class BaseVehicleManager {
    // MARK: - Configuration (Override in Subclasses)

    /// The vehicle type this manager handles (bus or tram)
    nonisolated var vehicleType: BusModel.VehicleType { .bus }

    /// The MQTT topic prefix for this vehicle type (e.g., "bus" or "tram")
    nonisolated var topicPrefix: String { "bus" }

    /// The GraphQL transport mode filter (e.g., "BUS" or "TRAM")
    nonisolated var transportMode: String { "BUS" }

    /// The UserDefaults key for storing favorites
    nonisolated var favoritesKey: String { "FavoriteLines" }

    /// Default favorite lines if none are saved
    var defaultFavorites: [BusLine] { [] }

    // MARK: - Shared State

    var vehicleList: [BusModel] = []
    var isConnected: Bool = false
    var error: AppError?

    var favoriteLines: [BusLine] = [] {
        didSet { saveFavorites() }
    }

    // MARK: - Internal State

    var vehicles: [Int: BusModel] = [:]
    var activeLines: [BusLine] = []
    var currentSubscriptions: Set<String> = []

    // MARK: - Dependencies

    var urlSession: URLSession
    private var connectOnStart: Bool

    private var _clientContainer: MQTTClientContainer?
    var client: MQTTClient? {
        get { _clientContainer?.client }
        set {
            if let newValue {
                _clientContainer = MQTTClientContainer(newValue)
            } else {
                _clientContainer = nil
            }
        }
    }

    let pendingBuffer = PendingBuffer()
    private var updateTimer: Timer?
    private var cleanupTimer: Timer?
    private var mockSimulationTimer: Timer?
    private var subscriptionTask: Task<Void, Never>?

    // MARK: - UI Testing

    var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITesting")
    }

    // MARK: - Initialization

    init(urlSession: URLSession = .shared, connectOnStart: Bool = true) {
        self.urlSession = urlSession
        self.connectOnStart = connectOnStart
    }

    func cleanup() {
        updateTimer?.invalidate()
        cleanupTimer?.invalidate()
        mockSimulationTimer?.invalidate()
        subscriptionTask?.cancel()
    }

    func setup() {
        loadFavorites()
        if connectOnStart {
            setupConnection()
        }
        startCleanupTimer()
        startUpdateTimer()
    }

    // MARK: - Connection Management

    func reconnect() {
        guard !isConnected else { return }
        Logger.busManager.info("\(String(describing: Self.self)): App became active, reconnecting MQTT...")
        startCleanupTimer()
        startUpdateTimer()
        setupConnection()
    }

    func disconnect() {
        guard isConnected else { return }
        Logger.busManager.info("\(String(describing: Self.self)): App backgrounded, disconnecting MQTT...")
        cleanup()
        Task {
            try? await client?.disconnect()
            self.isConnected = false
            self.currentSubscriptions.removeAll()
        }
    }

    private func setupConnection() {
        Task {
            if isConnected { return }

            if isUITesting {
                self.isConnected = true
                Logger.busManager.info("UI Testing: \(String(describing: Self.self)) skipping MQTT connection, starting simulation")
                startMockSimulation()
                return
            }

            do {
                let client = MQTTClient(
                    host: Secrets.mqttHost,
                    port: Secrets.mqttPort,
                    identifier: "HSL-App-\(String(describing: Self.self))-\(Int.random(in: 0...10000))",
                    eventLoopGroupProvider: .shared(NIOTSEventLoopGroup.singleton),
                    configuration: MQTTClient.Configuration(
                        userName: Secrets.mqttUsername,
                        password: Secrets.digitransitKey,
                        useSSL: true
                    )
                )
                self.client = client

                try await client.connect()

                client.addPublishListener(named: "\(String(describing: Self.self))Listener") { [weak self] result in
                    guard let self = self else { return }
                    if case .success(let publishInfo) = result {
                        self.processMessage(publishInfo)
                    }
                }

                self.isConnected = true
                Logger.busManager.info("\(String(describing: Self.self)): MQTT Connected")

                if !self.activeLines.isEmpty {
                    self.updateSubscriptions(selectedLines: self.activeLines)
                }

            } catch {
                Logger.busManager.error("\(String(describing: Self.self)): MQTT Connection failed: \(error)")
                self.isConnected = false
                self.error = .mqttError(error.localizedDescription)
            }
        }
    }

    // MARK: - Subscriptions

    func updateSubscriptions(selectedLines: [BusLine]) {
        self.activeLines = selectedLines

        guard let client = client, self.isConnected else { return }

        // Cancel any pending subscription task to prevent race conditions
        subscriptionTask?.cancel()

        subscriptionTask = Task {
            let newTopics = Set(selectedLines.map { "/hfp/v2/journey/ongoing/vp/\(topicPrefix)/+/+/\($0.routeId)/#" })
            let toSubscribe = newTopics.subtracting(currentSubscriptions)
            let toUnsubscribe = currentSubscriptions.subtracting(newTopics)

            do {
                if !toUnsubscribe.isEmpty {
                    try await client.unsubscribe(from: Array(toUnsubscribe))
                    Logger.busManager.debug("\(String(describing: Self.self)): Unsubscribed from \(toUnsubscribe.count) topics")
                }

                if !toSubscribe.isEmpty {
                    let subscriptions = toSubscribe.map { MQTTSubscribeInfo(topicFilter: $0, qos: .atMostOnce) }
                    _ = try await client.subscribe(to: subscriptions)
                    Logger.busManager.debug("\(String(describing: Self.self)): Subscribed to \(toSubscribe.count) topics")
                }
            } catch {
                Logger.busManager.error("\(String(describing: Self.self)): Subscription error: \(error)")
            }

            guard !Task.isCancelled else { return }

            self.currentSubscriptions = newTopics

            // Cleanup vehicles not in selected lines
            let selectedIds = Set(selectedLines.map { $0.routeId })
            let selectedNames = Set(selectedLines.map { $0.shortName })

            self.vehicles = self.vehicles.filter { vehicle in
                if let routeId = vehicle.value.routeId {
                    return selectedIds.contains(routeId)
                } else {
                    return selectedNames.contains(vehicle.value.lineName)
                }
            }
            self.vehicleList = self.vehicles.values.sorted { $0.id < $1.id }
        }
    }

    // MARK: - Message Handling

    nonisolated func processMessage(_ info: MQTTPublishInfo) {
        struct LocalVP: Decodable {
            let veh: Int
            let desi: String?
            let lat: Double?
            let long: Double?
            let hdg: Int?
            let tsi: TimeInterval?
        }
        struct LocalResponse: Decodable {
            let VP: LocalVP
        }

        var buffer = info.payload
        guard let data = buffer.readData(length: buffer.readableBytes) else { return }

        // Extract routeId from topic: /hfp/v2/journey/ongoing/vp/{type}/{op}/{veh}/{routeId}/...
        let parts = info.topicName.split(separator: "/")
        let routeId = parts.count > 8 ? String(parts[8]) : nil

        do {
            let response = try JSONDecoder().decode(LocalResponse.self, from: data)
            let vp = response.VP

            if let lat = vp.lat, let long = vp.long, let desi = vp.desi {
                let vehicle = BusModel(
                    id: vp.veh,
                    lineName: desi,
                    routeId: routeId,
                    latitude: lat,
                    longitude: long,
                    heading: vp.hdg,
                    timestamp: vp.tsi ?? Date().timeIntervalSince1970,
                    type: vehicleType
                )

                Task { await pendingBuffer.add(vehicle) }
            }
        } catch {
            Logger.busManager.debug("\(String(describing: Self.self)): Decoding skipped: \(error)")
        }
    }

    // MARK: - Search

    func searchLines(query: String) async throws -> [BusLine] {
        guard !query.isEmpty else { return [] }

        guard let url = URL(string: VehicleManagerConstants.graphQLEndpoint) else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Secrets.digitransitKey, forHTTPHeaderField: "digitransit-subscription-key")

        let graphqlQuery = """
        query SearchRoutes($name: String!) {
          routes(name: $name, transportModes: \(transportMode)) {
            gtfsId
            shortName
            longName
          }
        }
        """

        let body: [String: Any] = [
            "query": graphqlQuery,
            "variables": ["name": query]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkError("Invalid Response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw AppError.apiError("HTTP \(httpResponse.statusCode)")
            }

            struct SearchResponse: Decodable {
                let data: DataContainer?
            }
            struct DataContainer: Decodable {
                let routes: [Route]?
            }
            struct Route: Decodable {
                let gtfsId: String
                let shortName: String?
                let longName: String?
            }

            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            return decoded.data?.routes?.compactMap { route in
                guard let short = route.shortName else { return nil }
                return BusLine(id: route.gtfsId, shortName: short, longName: route.longName ?? "")
            } ?? []
        } catch {
            self.error = error as? AppError ?? AppError.networkError(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Favorites

    func toggleFavorite(_ line: BusLine) {
        if let index = favoriteLines.firstIndex(where: { $0.id == line.id }) {
            favoriteLines.remove(at: index)
        } else {
            favoriteLines.append(line)
        }
    }

    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteLines) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([BusLine].self, from: data) {
            self.favoriteLines = decoded
        } else {
            self.favoriteLines = defaultFavorites
        }
    }

    // MARK: - Mock Simulation

    func startMockSimulation() {
        // Override in subclass
    }

    func setMockSimulationTimer(_ timer: Timer) {
        mockSimulationTimer?.invalidate()
        mockSimulationTimer = timer
    }

    // MARK: - Update Timer

    private func startUpdateTimer() {
        updateTimer?.invalidate()

        updateTimer = Timer.scheduledTimer(withTimeInterval: VehicleManagerConstants.updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard !self.activeLines.isEmpty else { return }
                await self.flushUpdates()
            }
        }
    }

    private func flushUpdates() async {
        let updates = await pendingBuffer.take()
        guard !updates.isEmpty else { return }

        let now = Date().timeIntervalSince1970
        var hasChanges = false

        let selectedIds = Set(activeLines.map { $0.routeId })
        let selectedNames = Set(activeLines.map { $0.shortName })

        for (id, newVehicle) in updates {
            let isActive: Bool
            if let routeId = newVehicle.routeId {
                isActive = selectedIds.contains(routeId)
            } else {
                isActive = selectedNames.contains(newVehicle.lineName)
            }

            guard isActive else { continue }

            if self.vehicles[id] != newVehicle {
                self.vehicles[id] = newVehicle
                hasChanges = true
            }
        }

        // Prune stale vehicles
        let staleIds = self.vehicles.filter { now - $0.value.timestamp > VehicleManagerConstants.staleThreshold }.map { $0.key }
        if !staleIds.isEmpty {
            for id in staleIds {
                self.vehicles.removeValue(forKey: id)
            }
            hasChanges = true
        }

        if hasChanges {
            self.vehicleList = self.vehicles.values.sorted { $0.id < $1.id }
        }
    }

    // MARK: - Cleanup Timer

    private func startCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: VehicleManagerConstants.cleanupInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard !self.activeLines.isEmpty else { return }
                self.cleanupStaleVehicles()
            }
        }
    }

    private func cleanupStaleVehicles() {
        let now = Date().timeIntervalSince1970
        let beforeCount = vehicles.count

        self.vehicles = self.vehicles.filter { (now - $0.value.timestamp) < VehicleManagerConstants.staleThreshold }

        if vehicles.count != beforeCount {
            self.vehicleList = self.vehicles.values.sorted { $0.id < $1.id }
        }
    }

    // MARK: - MQTT Client Container

    private final class MQTTClientContainer {
        let client: MQTTClient
        init(_ client: MQTTClient) { self.client = client }
        deinit {
            try? client.syncShutdownGracefully()
        }
    }
}

// MARK: - Pending Buffer Actor

actor PendingBuffer {
    private var updates: [Int: BusModel] = [:]

    func add(_ vehicle: BusModel) {
        updates[vehicle.id] = vehicle
    }

    func take() -> [Int: BusModel] {
        let copy = updates
        updates.removeAll()
        return copy
    }
}
