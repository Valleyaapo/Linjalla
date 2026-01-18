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

// MARK: - Base Vehicle Manager

@MainActor
@Observable
class BaseVehicleManager {
    /// Shared JSON decoder for high-volume updates and persistence.
    private nonisolated(unsafe) static let decoder = JSONDecoder()

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

    private let graphQLService: DigitransitService
    private let connectOnStart: Bool

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

    private nonisolated let stream = VehicleStream()
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
        self.graphQLService = DigitransitService(
            urlSession: urlSession,
            digitransitKey: Secrets.digitransitKey
        )
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
        let client = self.client
        Task {
            try? await client?.disconnect()
            await stream.clearSubscriptions()
            await MainActor.run {
                self.isConnected = false
                self.currentSubscriptions.removeAll()
            }
        }
    }

    private func setupConnection() {
        Task { [weak self] in
            guard let self else { return }
            let alreadyConnected = await MainActor.run { self.isConnected }
            guard !alreadyConnected else { return }

            let isUITesting = await MainActor.run { self.isUITesting }
            if isUITesting {
                await MainActor.run {
                    self.isConnected = true
                    Logger.busManager.info("UI Testing: \(String(describing: Self.self)) skipping MQTT connection, starting simulation")
                    self.startMockSimulation()
                }
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

                await MainActor.run {
                    self.client = client
                }

                try await client.connect()

                client.addPublishListener(named: "\(String(describing: Self.self))Listener") { [weak self] result in
                    guard let self = self else { return }
                    if case .success(let publishInfo) = result {
                        self.processMessage(publishInfo)
                    }
                }

                await MainActor.run {
                    self.isConnected = true
                    Logger.busManager.info("\(String(describing: Self.self)): MQTT Connected")

                    if !self.activeLines.isEmpty {
                        self.updateSubscriptions(selectedLines: self.activeLines)
                    }
                }

            } catch {
                await MainActor.run {
                    Logger.busManager.error("\(String(describing: Self.self)): MQTT Connection failed: \(error)")
                    self.isConnected = false
                    self.error = .mqttError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Subscriptions

    func updateSubscriptions(selectedLines: [BusLine]) {
        self.activeLines = selectedLines

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
                    Logger.busManager.debug("\(String(describing: Self.self)): Unsubscribed from \(toUnsubscribe.count) topics")
                }

                if !toSubscribe.isEmpty {
                    let subscriptions = toSubscribe.map { MQTTSubscribeInfo(topicFilter: $0, qos: .atMostOnce) }
                    _ = try await client.subscribe(to: subscriptions)
                    Logger.busManager.debug("\(String(describing: Self.self)): Subscribed to \(toSubscribe.count) topics")
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

    nonisolated func processMessage(_ info: MQTTPublishInfo) {
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

        var buffer = info.payload
        guard let data = buffer.readData(length: buffer.readableBytes) else { return }

        // Extract routeId from topic (support multiple HFP layouts)
        let parts = info.topicName.split(separator: "/")
        let routeId: String? = parts.count > topicRouteIdIndex ? String(parts[topicRouteIdIndex]) : nil
        let normalizedRouteId = routeId?.replacingOccurrences(of: "HSL:", with: "")

        do {
            let response = try Self.decoder.decode(LocalResponse.self, from: data)
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

                Task { await stream.buffer(vehicle) }
            }
        } catch {
            Logger.busManager.debug("\(String(describing: Self.self)): Decoding skipped: \(error)")
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
           let decoded = try? Self.decoder.decode([BusLine].self, from: data) {
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
