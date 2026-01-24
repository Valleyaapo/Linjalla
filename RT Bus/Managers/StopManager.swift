//
//  StopManager.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import Foundation
import CoreLocation
import Observation
import OSLog
import QuartzCore
import SwiftUI

@MainActor
@Observable
final class StopManager {
    private(set) var allStops: [BusStop] = [] // Flattened, sorted list for View
    private(set) var error: AppError? // User-facing error
    private(set) var isLoading: Bool = false
    
    private var activeFetchCount = 0 {
        didSet { isLoading = activeFetchCount > 0 }
    }
    
    // Internal cache
    private var stops: [String: [BusStop]] = [:]
    private var fetchTasks: [String: Task<Void, Never>] = [:]
    private let graphQLService: DigitransitService
    
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var needsRebuild = false
    
    init(urlSession: URLSession = .shared) {
        self.graphQLService = DigitransitService(
            urlSession: urlSession,
            digitransitKey: Secrets.digitransitKey
        )
    }

    func clearError() {
        error = nil
    }
    
    // MARK: - API
    
    func updateStops(for lines: [BusLine]) {
        let currentLineIds = Set(lines.map { $0.id })
        
        // 1. Remove stops for lines no longer selected
        let linesToRemove = stops.keys.filter { !currentLineIds.contains($0) }
        for lineId in linesToRemove {
            stops.removeValue(forKey: lineId)
        }

        // Cancel in-flight fetches for deselected lines
        let tasksToCancel = fetchTasks.keys.filter { !currentLineIds.contains($0) }
        for lineId in tasksToCancel {
            fetchTasks[lineId]?.cancel()
            fetchTasks.removeValue(forKey: lineId)
        }
        
        // 2. Fetch missing stops
        for line in lines {
            if stops[line.id] == nil {
                fetchTasks[line.id]?.cancel()
                let task = Task {
                    await fetchStops(for: line)
                }
                fetchTasks[line.id] = task
            }
        }
        
        // 3. Rebuild (Immediate for removals)
        scheduleRebuildAllStops()
    }
    
    private func fetchStops(for line: BusLine) async {
        activeFetchCount += 1
        defer {
            activeFetchCount -= 1
            fetchTasks.removeValue(forKey: line.id)
        }
        
        do {
            let busStops = try await graphQLService.fetchStops(routeId: line.id)
            guard !Task.isCancelled else { return }
            self.error = nil
            self.stops[line.id] = busStops
            self.scheduleRebuildAllStops()
        } catch is CancellationError {
            return
        } catch {
            Logger.stopManager.error("Failed to fetch stops for \(line.shortName): \(error)")
            self.error = AppError.networkError(error.localizedDescription)
        }
    }
    
    func fetchDepartures(for stationId: String) async throws -> [Departure] {
        do {
            let departures = try await graphQLService.fetchDepartures(stationId: stationId)
            self.error = nil
            return departures
        } catch {
            Logger.stopManager.error("Fetch Departures failed: \(error)")
            let appError = AppError.networkError(error.localizedDescription)
            self.error = appError
            throw appError
        }
    }
    
    private func rebuildAllStops() {
        let uniqueStops = Set(self.stops.values.flatMap { $0 })
        // Stability check: only update if the collection truly changed
        let sortedStops = uniqueStops.sorted { $0.id < $1.id }
        if self.allStops != sortedStops {
            withAnimation(.easeInOut) {
                self.allStops = sortedStops
            }
        }
    }
    
    private func scheduleRebuildAllStops() {
        needsRebuild = true
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkFired() {
        displayLink?.invalidate()
        displayLink = nil
        guard needsRebuild else { return }
        needsRebuild = false
        rebuildAllStops()
    }
}
