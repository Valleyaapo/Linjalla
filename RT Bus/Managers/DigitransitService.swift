import Foundation
import OSLog

actor DigitransitService {
    private let urlSession: URLSession
    private let digitransitKey: String
    private let decoder = JSONDecoder()

    init(urlSession: URLSession = .shared, digitransitKey: String) {
        self.urlSession = urlSession
        self.digitransitKey = digitransitKey
    }

    func searchRoutes(query: String, transportMode: String) async throws -> [BusLine] {
        guard !query.isEmpty else { return [] }

        let request = try makeRequest(
            query: """
            query SearchRoutes($name: String!) {
              routes(name: $name, transportModes: \(transportMode)) {
                gtfsId
                shortName
                longName
              }
            }
            """,
            variables: ["name": query]
        )

        let response: GraphQLRouteResponse = try await fetch(request)
        let routes = response.data?.routes ?? []
        return routes.compactMap { route in
            guard let id = route.gtfsId, let short = route.shortName else { return nil }
            return BusLine(id: id, shortName: short, longName: route.longName ?? "")
        }
    }

    func fetchStops(routeId: String) async throws -> [BusStop] {
        let request = try makeRequest(
            query: """
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
            """,
            variables: ["id": routeId]
        )

        let response: GraphQLStopResponse = try await fetch(request)
        let patterns = response.data.route?.patterns ?? []
        let allStops = patterns.flatMap { $0.stops }
        let uniqueStops = Dictionary(grouping: allStops, by: { $0.gtfsId }).compactMap { (_, stops) in
            stops.first
        }
        return uniqueStops.map { stop in
            BusStop(id: stop.gtfsId, name: stop.name, latitude: stop.lat, longitude: stop.lon)
        }
    }

    func fetchDepartures(stationId: String) async throws -> [Departure] {
        let request = try makeRequest(
            query: """
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
            """,
            variables: ["stationId": stationId]
        )

        let response: GraphQLStopDeparturesResponse = try await fetch(request)
        guard let stoptimes = response.data.stop?.stoptimesWithoutPatterns else { return [] }
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
    }

    private func makeRequest(query: String, variables: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: VehicleManagerConstants.graphQLEndpoint) else {
            throw AppError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(digitransitKey, forHTTPHeaderField: "digitransit-subscription-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "variables": variables
        ])
        return request
    }

    private enum DigitransitError: Error {
        case httpStatus(Int)
    }

    private func fetch<T: Decodable>(_ request: URLRequest) async throws -> T {
        let maxRetries = 3
        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetries {
            try Task.checkCancellation()
            do {
                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.networkError("Invalid Response")
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw DigitransitError.httpStatus(httpResponse.statusCode)
                }

                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    Logger.network.error("Decoding error: \(error)")
                    throw AppError.decodingError(error.localizedDescription)
                }
            } catch {
                lastError = error
                if error is CancellationError {
                    throw error
                }

                guard attempt < maxRetries, shouldRetry(error: error) else {
                    throw mapError(error)
                }

                let delay = retryDelay(for: attempt)
                Logger.network.warning("Retrying Digitransit request in \(delay, format: .fixed(precision: 2))s (attempt \(attempt + 1))")
                try await Task.sleep(for: .seconds(delay))
                attempt += 1
            }
        }

        throw mapError(lastError ?? AppError.networkError("Unknown error"))
    }

    private func shouldRetry(error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .networkConnectionLost,
                .notConnectedToInternet,
                .timedOut,
                .cannotConnectToHost,
                .cannotFindHost
            ].contains(urlError.code)
        }

        if let digitransitError = error as? DigitransitError {
            switch digitransitError {
            case .httpStatus(let statusCode):
                return statusCode == 429 || (500...599).contains(statusCode)
            }
        }

        if case AppError.networkError = error {
            return true
        }

        return false
    }

    private func retryDelay(for attempt: Int) -> TimeInterval {
        let base: TimeInterval = 0.5
        let maxDelay: TimeInterval = 6.0
        let exponential = base * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5)
        return min(maxDelay, exponential + jitter)
    }

    private func mapError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        if let urlError = error as? URLError {
            return AppError.networkError(urlError.localizedDescription)
        }
        if let digitransitError = error as? DigitransitError {
            switch digitransitError {
            case .httpStatus(let statusCode):
                return AppError.apiError("HTTP \(statusCode)")
            }
        }
        return AppError.networkError(error.localizedDescription)
    }
}
