//
//  TrainManager.swift
//  RT Bus
//
//  Created by Assistant on 29.12.2025.
//

import Foundation
import CoreLocation
import Observation
import OSLog
import RTBusCore

@MainActor
@Observable
final class TrainManager {
    var error: AppError?
    var stations: [TrainStation] = []
    @ObservationIgnored var stationNames: [String: String] = [:]
    @ObservationIgnored private var metadataStations: [DigitrafficStation] = []
    @ObservationIgnored private let graphQLService: DigitransitService
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITesting")
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    init(urlSession: URLSession = .shared) {
        self.graphQLService = DigitransitService(
            urlSession: urlSession,
            digitransitKey: Secrets.digitransitKey
        )
    }
    
    func fetchMetadata() async {
        if isUITesting {
            stationNames = ["HKI": "Helsinki"]
            error = nil
            return
        }

        guard stationNames.isEmpty else { return }

        guard let url = URL(string: "https://rata.digitraffic.fi/api/v1/metadata/stations") else {
            Logger.network.error("Invalid metadata URL")
            self.error = AppError.networkError("Invalid metadata URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

            let stations: [DigitrafficStation] = try await NetworkService.shared.fetch(request, decoder: decoder)
            self.error = nil
            self.metadataStations = stations

            for station in stations {
                // Clean up name (e.g., "Helsinki asema" -> "Helsinki")
                let cleanName = station.stationName.replacingOccurrences(of: " asema", with: "")
                stationNames[station.stationShortCode] = cleanName
            }
        } catch {
            Logger.network.error("Failed to fetch station metadata: \(error)")
            self.error = AppError.networkError(error.localizedDescription)
        }
    }

    func fetchStations() async {
        if isUITesting {
            stations = [
                TrainStation(
                    id: "HKI",
                    name: "Helsinki",
                    latitude: 60.17188819980838,
                    longitude: 24.94138140521009
                )
            ]
            error = nil
            return
        }

        await fetchMetadata()

        do {
            let railStations = try await graphQLService.fetchRailStations()
            stations = railStations
                .map { station in
                    let codeName = stationCode(from: station.id).flatMap { stationNames[$0] }
                    let nearestName = nearestStationName(for: station)
                    let name = codeName ?? nearestName ?? station.name
                    return TrainStation(
                        id: station.id,
                        name: name,
                        latitude: station.latitude,
                        longitude: station.longitude
                    )
                }
                .sorted { $0.name < $1.name }
        } catch {
            Logger.network.error("Failed to fetch rail stations: \(error)")
            self.error = AppError.networkError(error.localizedDescription)
        }
    }

    private func nearestStationName(for station: BusStop) -> String? {
        let target = CLLocation(latitude: station.latitude, longitude: station.longitude)
        var best: (name: String, distance: CLLocationDistance)?

        for metadata in metadataStations {
            guard let lat = metadata.latitude, let lon = metadata.longitude else { continue }
            let distance = target.distance(from: CLLocation(latitude: lat, longitude: lon))
            if best == nil || distance < best!.distance {
                best = (metadata.stationName, distance)
            }
        }

        guard let best, best.distance < 800 else { return nil }
        return best.name.replacingOccurrences(of: " asema", with: "")
    }
    
    func fetchDepartures(stationCode: String = "HKI") async throws -> [Departure] {
        if isUITesting {
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let serviceDay = Int(startOfDay.timeIntervalSince1970)
            let secondsSinceMidnight = Int(now.timeIntervalSince1970) - serviceDay
            let departure = secondsSinceMidnight + 300
            return [
                Departure(
                    id: "train_I_HKI_\(departure)",
                    lineName: "I",
                    routeId: nil,
                    headsign: "via Tikkurila",
                    scheduledTime: departure,
                    realtimeTime: departure,
                    serviceDay: serviceDay,
                    platform: "1"
                )
            ]
        }

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
    
    func processTrain(_ train: DigitrafficTrain, for stationCode: String, at now: Date) -> Departure? {
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
        
        // Use stable ID to prevent unnecessary UI re-renders on data refresh
        let id = "train_\(train.trainNumber)_\(stationCode)_\(Int(departureRow.scheduledTime.timeIntervalSince1970))"
        return Departure(
            id: id,
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
    let latitude: Double?
    let longitude: Double?
}

private func stationCode(from gtfsId: String) -> String? {
    if let underscore = gtfsId.split(separator: "_").last, underscore != gtfsId[...] {
        return String(underscore)
    }
    if let colon = gtfsId.split(separator: ":").last {
        return String(colon)
    }
    return nil
}
