import Foundation
import OSLog

@MainActor
final class DigitransitService {
    private let urlSession: URLSession
    private let digitransitKey: String

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
        guard let firstPattern = response.data.route?.patterns.first else { return [] }
        return firstPattern.stops.map { stop in
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

    private func fetch<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid Response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError.apiError("HTTP \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Logger.network.error("Decoding error: \(error)")
            throw error
        }
    }
}
