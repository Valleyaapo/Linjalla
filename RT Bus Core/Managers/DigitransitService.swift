import Foundation
import OSLog

// Pre-computed queries
private enum Queries {
    static let routeStops = """
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

    static let departures = """
        query GetDepartures($stationId: String!, $count: Int!) {
          stop(id: $stationId) {
            stoptimesWithoutPatterns(numberOfDepartures: $count) {
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
                  gtfsId
                  shortName
                }
              }
            }
          }
        }
        """

    static let stationDepartures = """
        query GetStationDepartures($stationId: String!, $count: Int!) {
          station(id: $stationId) {
            stoptimesWithoutPatterns(numberOfDepartures: $count, omitNonPickups: true) {
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
                  gtfsId
                  shortName
                }
              }
            }
          }
        }
        """
}

public actor DigitransitService {
    private let client: GraphQLClient

    public init(urlSession: URLSession = .shared, digitransitKey: String) {
        self.client = GraphQLClient(
            session: urlSession,
            apiKey: digitransitKey,
            endpoint: VehicleManagerConstants.graphQLEndpoint
        )
    }

    public func searchRoutes(query: String, transportMode: String) async throws -> [BusLine] {
        guard !query.isEmpty else { return [] }

        let searchQuery = """
            query SearchRoutes($name: String!) {
              routes(name: $name, transportModes: [\(transportMode)]) {
                gtfsId
                shortName
                longName
              }
            }
            """

        let response: GraphQLRouteResponse = try await client.request(
            query: searchQuery,
            variables: SearchRoutesVars(name: query),
            as: GraphQLRouteResponse.self
        )
        let routes = response.data?.routes ?? []
        return routes.compactMap { route in
            guard let id = route.gtfsId, let short = route.shortName else { return nil }
            return BusLine(id: id, shortName: short, longName: route.longName ?? "")
        }
    }

    public func fetchStops(routeId: String) async throws -> [BusStop] {
        let response: GraphQLStopResponse = try await client.request(
            query: Queries.routeStops,
            variables: RouteStopsVars(id: routeId),
            as: GraphQLStopResponse.self
        )
        let patterns = response.data.route?.patterns ?? []
        let allStops = patterns.flatMap { $0.stops }
        let uniqueStops = Dictionary(grouping: allStops, by: { $0.gtfsId }).compactMap { (_, stops) in
            stops.first
        }
        return uniqueStops.map { stop in
            BusStop(
                id: stop.gtfsId,
                name: stop.name,
                latitude: stop.lat,
                longitude: stop.lon
            )
        }
    }

    public func fetchDepartures(
        request: DeparturesRequest,
        filter: DepartureFilterInput? = nil
    ) async throws -> [Departure] {
        let response: GraphQLStopDeparturesResponse = try await client.request(
            query: Queries.departures,
            variables: DeparturesVars(
                stationId: request.stationId,
                count: request.count
            ),
            as: GraphQLStopDeparturesResponse.self
        )
        guard let stoptimes = response.data.stop?.stoptimesWithoutPatterns else { return [] }
        let departures: [Departure] = stoptimes.compactMap { stoptime in
            guard stoptime.pickupType != "NONE" else { return nil }
            guard let route = stoptime.trip?.route,
                  let lineName = route.shortName else { return nil }

            return Departure(
                lineName: lineName,
                routeId: route.gtfsId,
                headsign: stoptime.headsign ?? "Unknown",
                scheduledTime: stoptime.scheduledDeparture,
                realtimeTime: stoptime.realtimeDeparture,
                serviceDay: stoptime.serviceDay,
                platform: stoptime.stop?.platformCode
            )
        }
        return DepartureFiltering.apply(departures, filter: filter)
    }

    public func fetchStationDepartures(
        request: DeparturesRequest,
        filter: DepartureFilterInput? = nil
    ) async throws -> [Departure] {
        let response: GraphQLStationDeparturesResponse = try await client.request(
            query: Queries.stationDepartures,
            variables: DeparturesVars(
                stationId: request.stationId,
                count: request.count
            ),
            as: GraphQLStationDeparturesResponse.self
        )
        guard let stoptimes = response.data.station?.stoptimesWithoutPatterns else { return [] }
        let departures: [Departure] = stoptimes.compactMap { stoptime in
            guard stoptime.pickupType != "NONE" else { return nil }
            guard let route = stoptime.trip?.route,
                  let lineName = route.shortName else { return nil }

            return Departure(
                lineName: lineName,
                routeId: route.gtfsId,
                headsign: stoptime.headsign ?? "Unknown",
                scheduledTime: stoptime.scheduledDeparture,
                realtimeTime: stoptime.realtimeDeparture,
                serviceDay: stoptime.serviceDay,
                platform: stoptime.stop?.platformCode
            )
        }
        return DepartureFiltering.apply(departures, filter: filter)
    }
}
