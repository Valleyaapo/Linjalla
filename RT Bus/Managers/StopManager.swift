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
class StopManager {
    var allStops: [BusStop] = [] // Flattened, sorted list for View
    var error: AppError? // User-facing error
    var isLoading: Bool = false
    
    private var activeFetchCount = 0 {
        didSet { isLoading = activeFetchCount > 0 }
    }
    
    // Internal cache
    private var stops: [String: [BusStop]] = [:]
    private var urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - API
    
    func updateStops(for lines: [BusLine]) {
        let currentLineIds = Set(lines.map { $0.id })
        
        // 1. Remove stops for lines no longer selected
        let linesToRemove = stops.keys.filter { !currentLineIds.contains($0) }
        for lineId in linesToRemove {
            stops.removeValue(forKey: lineId)
        }
        
        // 2. Fetch missing stops
        for line in lines {
            if stops[line.id] == nil {
                Task {
                    await fetchStops(for: line)
                }
            }
        }
        
        // 3. Rebuild (Immediate for removals)
        rebuildAllStops()
    }
    
    private func fetchStops(for line: BusLine) async {
        activeFetchCount += 1
        defer { activeFetchCount -= 1 }
        
        let url = URL(string: VehicleManagerConstants.graphQLEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Secrets.digitransitKey, forHTTPHeaderField: "digitransit-subscription-key")
        
        let graphqlQuery = """
        query GetRouteStops($id: String!) {
          route(id: $id) {
            patterns {
              stops {
                gtfsId
                name
                lat
                lon
              }
            }
          }
        }
        """
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "query": graphqlQuery,
                "variables": ["id": line.id]
            ])
            
            let (data, response) = try await self.urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw AppError.networkError("Fetch Stops Failed")
            }
            
            let result = try JSONDecoder().decode(GraphQLStopResponse.self, from: data)
            
            if let firstPattern = result.data.route?.patterns.first {
                let busStops = firstPattern.stops.map { stop in
                    BusStop(id: stop.gtfsId, name: stop.name, latitude: stop.lat, longitude: stop.lon)
                }
                
                self.stops[line.id] = busStops
                self.rebuildAllStops()
            }
        } catch {
            Logger.stopManager.error("Failed to fetch stops for \(line.shortName): \(error)")
        }
    }
    
    func fetchDepartures(for stationId: String) async throws -> [Departure] {
        let url = URL(string: VehicleManagerConstants.graphQLEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Secrets.digitransitKey, forHTTPHeaderField: "digitransit-subscription-key")
        
        let graphqlQuery = """
        query GetDepartures($stationId: String!) {
          stop(id: $stationId) {
            stoptimesWithoutPatterns(numberOfDepartures: \(MapConstants.departuresFetchCount)) {
              scheduledDeparture
              realtimeDeparture
              serviceDay
              headsign
              pickupType
              stop {
                platformCode
              }
              trip {
                route {
                  shortName
                }
              }
            }
          }
        }
        """
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "query": graphqlQuery,
                "variables": ["stationId": stationId]
            ])
            
            let (data, response) = try await self.urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw AppError.networkError("Fetch Departures Failed")
            }
            
            let result = try JSONDecoder().decode(GraphQLStopDeparturesResponse.self, from: data)
            
            guard let stoptimes = result.data.stop?.stoptimesWithoutPatterns else { return [] }
            
            return stoptimes.compactMap { stoptime in
                guard stoptime.pickupType != "NONE" else { return nil }
                guard let lineName = stoptime.trip?.route?.shortName else { return nil }
                
                return Departure(
                    lineName: lineName,
                    headsign: stoptime.headsign ?? "Unknown",
                    scheduledTime: stoptime.scheduledDeparture,
                    realtimeTime: stoptime.realtimeDeparture,
                    serviceDay: stoptime.serviceDay,
                    platform: stoptime.stop?.platformCode
                )
            }
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



// MARK: - API Response Models

struct GraphQLStopDeparturesResponse: Codable, Sendable {
    let data: GraphQLStopDeparturesData
}
struct GraphQLStopDeparturesData: Codable, Sendable {
    let stop: GraphQLStation?
}
// Recycling GraphQLStation structure but mapped to 'stop' field now
struct GraphQLStation: Codable, Sendable {
    let stoptimesWithoutPatterns: [GraphQLStoptime]
}
struct GraphQLStoptime: Codable, Sendable {
    let scheduledDeparture: Int
    let realtimeDeparture: Int
    let serviceDay: Int
    let headsign: String?
    let pickupType: String?
    let stop: GraphQLStopShortPlatform?
    let trip: GraphQLTrip?
}
struct GraphQLStopShortPlatform: Codable, Sendable {
    let platformCode: String?
}
struct GraphQLTrip: Codable, Sendable {
    let route: GraphQLRouteShort?
}
struct GraphQLRouteShort: Codable, Sendable {
    let shortName: String?
}

struct GraphQLStopResponse: Codable, Sendable {
    let data: GraphQLStopData
}
struct GraphQLStopData: Codable, Sendable {
    let route: GraphQLRouteWithPatterns?
}
struct GraphQLRouteWithPatterns: Codable, Sendable {
    let patterns: [GraphQLPattern]
}
struct GraphQLPattern: Codable, Sendable {
    let stops: [GraphQLStop]
}
struct GraphQLStop: Codable, Sendable {
    let gtfsId: String
    let name: String
    let lat: Double
    let lon: Double
}
