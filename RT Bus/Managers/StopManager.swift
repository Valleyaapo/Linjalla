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
        rebuildAllStops()
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
            self.stops[line.id] = busStops
            self.rebuildAllStops()
        } catch is CancellationError {
            return
        } catch {
            Logger.stopManager.error("Failed to fetch stops for \(line.shortName): \(error)")
        }
    }
    
    func fetchDepartures(for stationId: String) async throws -> [Departure] {
        do {
            return try await graphQLService.fetchDepartures(stationId: stationId)
        } catch {
            Logger.stopManager.error("Fetch Departures failed: \(error)")
            throw AppError.networkError(error.localizedDescription)
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
}


