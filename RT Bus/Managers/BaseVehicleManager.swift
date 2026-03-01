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
import RTBusCore

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
    nonisolated var transportMode: TransportMode { .bus }

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
    
    @ObservationIgnored var vehicles: [Int: BusModel] = [:]
    @ObservationIgnored var activeLines: [BusLine] = []
    @ObservationIgnored var currentSubscriptions: Set<String> = []

    @ObservationIgnored private var vehicleUpdateStream: AsyncStream<BusModel>?
    @ObservationIgnored private var vehicleUpdateContinuation: AsyncStream<BusModel>.Continuation?
    @ObservationIgnored private var consumerTask: Task<Void, Never>?
    @ObservationIgnored var vehicleUpdateBufferLimit = 1_000

    // Shared decoder to reduce allocation overhead in high-frequency updates
    @ObservationIgnored private let decoder = JSONDecoder()

    // MARK: - Dependencies

    @ObservationIgnored private let graphQLService: DigitransitService
    @ObservationIgnored private let connectOnStart: Bool

    @ObservationIgnored private var _clientContainer: MQTTClientContainer?
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

    @ObservationIgnored let stream = VehicleStream()
    @ObservationIgnored private var updateLoopTask: Task<Void, Never>?
    @ObservationIgnored private var cleanupLoopTask: Task<Void, Never>?
    @ObservationIgnored private var mockSimulationTimer: Timer?
    @ObservationIgnored private var subscriptionTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var isConnecting = false
    @ObservationIgnored private var connectionAttempts = 0

    private var isMQTTDisabled: Bool {
        false
    }

    // MARK: - UI Testing

    var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITesting")
    }

    // MARK: - Initialization

    init(urlSession: URLSession = .shared, connectOnStart: Bool = true) {
        self.graphQLService = DigitransitService(
            urlSession: urlSession,
            digitransitKey: Secrets.digitransitKey
        )
        self.connectOnStart = connectOnStart
    }

    func cleanup() {
        updateLoopTask?.cancel()
        cleanupLoopTask?.cancel()
        mockSimulationTimer?.invalidate()
        subscriptionTask?.cancel()
        reconnectTask?.cancel()
        consumerTask?.cancel()
        vehicleUpdateContinuation?.finish()
        consumerTask = nil
        vehicleUpdateContinuation = nil
        vehicleUpdateStream = nil
        updateLoopTask = nil
        cleanupLoopTask = nil
    }

    func setup() {
        loadFavorites()
        if vehicleUpdateContinuation == nil {
            setupVehicleUpdateStream()
        }
        if isMQTTDisabled {
        } else if connectOnStart {
            setupConnection()
        }
        startCleanupLoop()
        startUpdateLoop()
    }

    // MARK: - Connection Management

    func reconnect() {
        guard !isConnected else { return }
        guard !isMQTTDisabled else {
            return
        }
        if vehicleUpdateContinuation == nil {
            setupVehicleUpdateStream()
        }
        startCleanupLoop()
        startUpdateLoop()
        setupConnection()
    }

    func disconnect() {
        guard isConnected else { return }
        cleanup()
        vehicles.removeAll()
        vehicleList.removeAll()
        let client = self.client
        Task {
            try? await client?.disconnect()
            await stream.clearSubscriptions()
            await MainActor.run {
                self.isConnected = false
                self.currentSubscriptions.removeAll()
                self.isConnecting = false
            }
        }
    }

    private func setupVehicleUpdateStream() {
        let (updateStream, continuation) = AsyncStream.makeStream(
            of: BusModel.self,
            bufferingPolicy: .bufferingNewest(vehicleUpdateBufferLimit)
        )
        self.vehicleUpdateStream = updateStream
        self.vehicleUpdateContinuation = continuation

        let bufferStream = stream
        self.consumerTask = Task {
            for await vehicle in updateStream {
                await bufferStream.buffer(vehicle)
            }
        }
    }

    private func setupConnection() {
        Task { [weak self] in
            guard let self else { return }
            let alreadyConnected = await MainActor.run { self.isConnected || self.isConnecting }
            guard !alreadyConnected else { return }
            await MainActor.run {
                self.isConnecting = true
            }

            let isUITesting = await MainActor.run { self.isUITesting }
            if isUITesting {
                await MainActor.run {
                    self.isConnected = true
                    self.isConnecting = false
                    self.startMockSimulation()
                }
                return
            }

            do {
                let client = MQTTClient(
                    host: Secrets.mqttHost,
                    port: Secrets.mqttPort,
                    identifier: "HSL-App-\(String(describing: Self.self))-\(UUID().uuidString)",
                    eventLoopGroupProvider: .shared(NIOTSEventLoopGroup.singleton),
                    configuration: MQTTClient.Configuration(
                        userName: Secrets.mqttUsername,
                        password: Secrets.digitransitKey,
                        useSSL: true
                    )
                )

                await MainActor.run {
                    self.client = client
                }

                try await client.connect()

                client.addPublishListener(named: "\(String(describing: Self.self))Listener") { [weak self] result in
                    guard let self = self else { return }
                    if case .success(let publishInfo) = result {
                        var buffer = publishInfo.payload
                        guard let data = buffer.readData(length: buffer.readableBytes) else { return }
                        let topic = publishInfo.topicName
                        Task { @MainActor in
                            self.processMessage(topicName: topic, payload: data)
                        }
                    }
                }

                await MainActor.run {
                    self.isConnected = true
                    self.isConnecting = false
                    self.connectionAttempts = 0
                    self.error = nil

                    if !self.activeLines.isEmpty {
                        self.updateSubscriptions(selectedLines: self.activeLines)
                    }
                }

            } catch {
                let attempt = await MainActor.run { () -> Int in
                    Logger.busManager.error("\(String(describing: Self.self)): MQTT Connection failed: \(error)")
                    self.isConnected = false
                    self.isConnecting = false
                    self.connectionAttempts += 1
                    return self.connectionAttempts
                }

                guard attempt <= VehicleManagerConstants.mqttReconnectMaxAttempts else {
                    await MainActor.run {
                        self.error = .mqttError(error.localizedDescription)
                    }
                    return
                }

                let delay = mqttRetryDelay(for: attempt)
                Logger.busManager.warning("\(String(describing: Self.self)): Retry MQTT connection in \(delay, format: .fixed(precision: 2))s (attempt \(attempt))")
                reconnectTask?.cancel()
                reconnectTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self?.setupConnection()
                    }
                }
            }
        }
    }

    private func mqttRetryDelay(for attempt: Int) -> TimeInterval {
        let base = VehicleManagerConstants.mqttReconnectBaseDelay
        let maxDelay = VehicleManagerConstants.mqttReconnectMaxDelay
        let exponential = base * pow(2.0, Double(max(0, attempt - 1)))
        let jitter = Double.random(in: 0...0.5)
        return min(maxDelay, exponential + jitter)
    }

    // MARK: - Subscriptions

    func updateSubscriptions(selectedLines: [BusLine]) {
        self.activeLines = selectedLines
        if selectedLines.isEmpty {
            stopLoops()
        } else {
            startUpdateLoop()
            startCleanupLoop()
        }

        guard let client = client, self.isConnected else { return }

        // Cancel any pending subscription task to prevent race conditions
        subscriptionTask?.cancel()

        let selections = selectedLines.map { RouteSelection(id: $0.id, routeId: $0.routeId) }
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            guard !Task.isCancelled else { return }
            let topicPrefix = await MainActor.run { self.topicPrefix }
            guard !Task.isCancelled else { return }
            let change = await stream.subscriptionChange(selections: selections, topicPrefix: topicPrefix)
            let newTopics = change.newTopics
            let toSubscribe = Set(change.toSubscribe)
            let toUnsubscribe = Set(change.toUnsubscribe)

            do {
                if !toUnsubscribe.isEmpty {
                    try await client.unsubscribe(from: Array(toUnsubscribe))
                }

                if !toSubscribe.isEmpty {
                    let subscriptions = toSubscribe.map { MQTTSubscribeInfo(topicFilter: $0, qos: .atMostOnce) }
                    _ = try await client.subscribe(to: subscriptions)
                }
            } catch {
                if let mqttError = error as? MQTTError, case .noConnection = mqttError {
                    await MainActor.run { [weak self] in
                        self?.isConnected = false
                        self?.currentSubscriptions.removeAll()
                        self?.setupConnection()
                    }
                    return
                }
                Logger.busManager.error("\(String(describing: Self.self)): Subscription error: \(error)")
            }

            guard !Task.isCancelled else { return }

            let applied = await stream.applySubscriptionUpdate(requestId: change.requestId, newTopics: newTopics)
            guard applied else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.currentSubscriptions = newTopics

                // Cleanup vehicles not in selected lines
                let selectedIds = Set(selectedLines.map { $0.routeId })
                let selectedNames = Set(selectedLines.map { $0.shortName })

                self.vehicles = self.vehicles.filter { vehicle in
                    if let routeId = vehicle.value.routeId {
                        let normalized = routeId.replacingOccurrences(of: "HSL:", with: "")
                        return selectedIds.contains(normalized)
                    } else {
                        return selectedNames.contains(vehicle.value.lineName)
                    }
                }
                self.vehicleList = self.vehicles.values.sorted { $0.id < $1.id }
            }
        }
    }

    // MARK: - Message Handling

    @MainActor
    func processMessage(topicName: String, payload: Data) {
        let topicRouteIdIndex = 8
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

        // Extract routeId from topic (support multiple HFP layouts)
        let parts = topicName.split(separator: "/")
        let routeId: String? = parts.count > topicRouteIdIndex ? String(parts[topicRouteIdIndex]) : nil
        let normalizedRouteId = routeId?.replacingOccurrences(of: "HSL:", with: "")

        do {
            let response = try decoder.decode(LocalResponse.self, from: payload)
            let vp = response.VP

            if let lat = vp.lat, let long = vp.long, let desi = vp.desi {
                let vehicle = BusModel(
                    id: vp.veh,
                    lineName: desi,
                    routeId: normalizedRouteId,
                    latitude: lat,
                    longitude: long,
                    heading: vp.hdg,
                    timestamp: vp.tsi ?? Date().timeIntervalSince1970,
                    type: vehicleType
                )
                vehicleUpdateContinuation?.yield(vehicle)
            }
        } catch {
            Logger.busManager.error("\(String(describing: Self.self)): Failed to decode MQTT payload: \(error)")
        }
    }

    // MARK: - Search

    func searchLines(query: String) async throws -> [BusLine] {
        do {
            return try await graphQLService.searchRoutes(query: query, transportMode: transportMode)
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
           let decoded = try? decoder.decode([BusLine].self, from: data) {
            self.favoriteLines = decoded
        } else {
            self.favoriteLines = defaultFavorites
        }
    }

    // MARK: - Mock Simulation

    func startMockSimulation() {
        // Override in subclass
    }

    func bufferMockVehicle(_ vehicle: BusModel) {
        Task { await stream.buffer(vehicle) }
    }

    func setMockSimulationTimer(_ timer: Timer) {
        mockSimulationTimer?.invalidate()
        mockSimulationTimer = timer
    }

    // MARK: - Update Timer

    private func startUpdateLoop() {
        guard !activeLines.isEmpty else { return }
        if let task = updateLoopTask, !task.isCancelled { return }
        updateLoopTask?.cancel()

        updateLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(VehicleManagerConstants.updateInterval))
                guard let self = self, !Task.isCancelled else { return }
                let hasActiveLines = await MainActor.run { !self.activeLines.isEmpty }
                guard hasActiveLines else { continue }
                await self.flushUpdates()
            }
        }
    }

    private func flushUpdates() async {
        let updates = await stream.drain()
        guard !updates.isEmpty else { return }

        let now = Date().timeIntervalSince1970
        var hasChanges = false

        let selectedIds = Set(activeLines.map { $0.routeId })
        let selectedNames = Set(activeLines.map { $0.shortName })

        for (id, newVehicle) in updates {
            let isActive: Bool
            if let routeId = newVehicle.routeId {
                let normalized = routeId.replacingOccurrences(of: "HSL:", with: "")
                isActive = selectedIds.contains(normalized)
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

    private func startCleanupLoop() {
        guard !activeLines.isEmpty else { return }
        if let task = cleanupLoopTask, !task.isCancelled { return }
        cleanupLoopTask?.cancel()
        cleanupLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(VehicleManagerConstants.cleanupInterval))
                guard let self = self, !Task.isCancelled else { return }
                let hasActiveLines = await MainActor.run { !self.activeLines.isEmpty }
                guard hasActiveLines else { continue }
                await MainActor.run {
                    self.cleanupStaleVehicles()
                }
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

    private func stopLoops() {
        updateLoopTask?.cancel()
        cleanupLoopTask?.cancel()
        updateLoopTask = nil
        cleanupLoopTask = nil
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
