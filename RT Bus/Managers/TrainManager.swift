//
//  TrainManager.swift
//  RT Bus
//
//  Created by Assistant on 29.12.2025.
//

import Foundation
import Combine
import Observation
import OSLog

@MainActor
@Observable
final class TrainManager {
    private var stationNames: [String: String] = [:]
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    init() {}
    
    func fetchMetadata() async {
        guard stationNames.isEmpty else { return }
        
        do {
            guard let url = URL(string: "https://rata.digitraffic.fi/api/v1/metadata/stations") else {
                Logger.network.error("Invalid metadata URL")
                return
            }
            var request = URLRequest(url: url)
            request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
            
            let stations: [DigitrafficStation] = try await NetworkService.shared.fetch(request, decoder: decoder)
            
            for station in stations {
                // Clean up name (e.g., "Helsinki asema" -> "Helsinki")
                let cleanName = station.stationName.replacingOccurrences(of: " asema", with: "")
                stationNames[station.stationShortCode] = cleanName
            }
        } catch {
            Logger.network.error("Failed to fetch station metadata: \(error)")
        }
    }
    
    func fetchDepartures(stationCode: String = "HKI") async throws -> [Departure] {
        await fetchMetadata()
        
        // Fetch 20 departing trains, exclude non-stopping
        guard let url = URL(string: "https://rata.digitraffic.fi/api/v1/live-trains/station/\(stationCode)?departing_trains=40&include_nonstopping=false") else {
            throw AppError.networkError("Invalid station URL")
        }
        var request = URLRequest(url: url)
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        
        let trains: [DigitrafficTrain] = try await NetworkService.shared.fetch(request, decoder: decoder)
        
        let now = Date()
        
        return trains.compactMap { processTrain($0, for: stationCode, at: now) }
        .sorted { $0.departureDate < $1.departureDate }
    }
    
    private func processTrain(_ train: DigitrafficTrain, for stationCode: String, at now: Date) -> Departure? {
        // Filter for Commuter trains only (Regional)
        guard train.trainCategory == "Commuter" else { return nil }
        
        // Find the departure row for the specified station
        // Breaking this up for compiler checking speed
        let rows = train.timeTableRows
        guard let departureRow = rows.first(where: {
            $0.stationShortCode == stationCode &&
            $0.type == "DEPARTURE" &&
            $0.commercialStop == true
        }) else { return nil }
        
        // Determine time (scheduled or live estimate)
        let time = departureRow.liveEstimateTime ?? departureRow.scheduledTime
        
        // Filter past trains (with 1 min grace period for trains still at platform)
        guard time > now.addingTimeInterval(-60) else { return nil }
        
        // Determine Headsign
        let lineId = train.commuterLineID ?? ""
        let destCode = train.timeTableRows.last?.stationShortCode ?? ""
        var destination = stationNames[destCode] ?? destCode
        
        // Special handling for Ring Rail (I/P) departing from Helsinki
        if stationCode == "HKI" && (lineId == "I" || lineId == "P") {
            if destCode == "HKI" {
                // Try to find a meaningful intermediate point
                if lineId == "I" {
                    destination = "via Tikkurila"
                } else {
                    destination = "via Myyrmäki"
                }
            }
        }
        
        // Final check: if it's the very last stop in the timetable, it's not a departure
        // Note: Using pointer identity (===) might be tricky with value types (structs).
        // It's safer to compare indices or timestamps.
        // But since we found the row in `rows`, and `rows` is an array of structs, we can't use ===.
        // Instead, check if the found row is the last one in the list.
        if let lastRow = rows.last {
            // Compare identifying properties (time + station + type)
            // or just ensure the departure row index < last row index
            if departureRow.scheduledTime == lastRow.scheduledTime &&
                departureRow.stationShortCode == lastRow.stationShortCode &&
                departureRow.type == lastRow.type {
                return nil
            }
        }
        
        return Departure(
            lineName: lineId,
            routeId: nil,
            headsign: destination,
            scheduledTime: 0,
            realtimeTime: Int(time.timeIntervalSince1970),
            serviceDay: 0,
            platform: departureRow.commercialTrack
        )
    }
}

// MARK: - Digitraffic Models

struct DigitrafficTrain: Codable {
    let trainNumber: Int
    let trainCategory: String
    let commuterLineID: String?
    let timeTableRows: [DigitrafficTimeTableRow]
}

struct DigitrafficTimeTableRow: Codable {
    let stationShortCode: String
    let type: String // "ARRIVAL" or "DEPARTURE"
    let scheduledTime: Date
    let liveEstimateTime: Date?
    let commercialTrack: String?
    let commercialStop: Bool?
    let trainStopping: Bool?
}

struct DigitrafficStation: Codable {
    let stationName: String
    let stationShortCode: String
}
