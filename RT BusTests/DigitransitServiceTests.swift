//
//  DigitransitServiceTests.swift
//  RT BusTests
//
//  GraphQL service regression tests
//

import Testing
import Foundation
@testable import RTBusCore

@MainActor
@Suite(.serialized)
struct DigitransitServiceTests {
    final class DigitransitServiceTestURLProtocol: URLProtocol {
        nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

        override class func canInit(with request: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                fatalError("Handler is unavailable.")
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                if let data {
                    client?.urlProtocol(self, didLoad: data)
                }
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }
    @Test
    func searchRoutesReturnsLines() async throws {
        let (service, _) = makeService()

        DigitransitServiceTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "routes": [
                  { "gtfsId": "HSL:123", "shortName": "123", "longName": "Test Line" }
                ]
              }
            }
            """.data(using: .utf8)
            return (response, data)
        }

        let lines = try await service.searchRoutes(query: "123", transportMode: .bus)
        #expect(lines.count == 1)
        #expect(lines.first?.id == "HSL:123")
        #expect(lines.first?.shortName == "123")
        #expect(lines.first?.longName == "Test Line")
    }

    @Test
    func fetchStopsMapsToBusStops() async throws {
        let (service, _) = makeService()

        DigitransitServiceTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "route": {
                  "patterns": [
                    {
                      "stops": [
                        { "gtfsId": "HSL:STOP1", "name": "Stop 1", "lat": 60.1, "lon": 24.9 }
                      ]
                    }
                  ]
                }
              }
            }
            """.data(using: .utf8)
            return (response, data)
        }

        let stops = try await service.fetchStops(routeId: "HSL:123")
        #expect(stops.count == 1)
        #expect(stops.first?.id == "HSL:STOP1")
        #expect(stops.first?.name == "Stop 1")
    }

    @Test
    func fetchStopsMergesPatternsUniquely() async throws {
        let (service, _) = makeService()

        DigitransitServiceTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "route": {
                  "patterns": [
                    {
                      "stops": [
                        { "gtfsId": "HSL:STOP1", "name": "Stop 1", "lat": 60.1, "lon": 24.9 },
                        { "gtfsId": "HSL:STOP2", "name": "Stop 2", "lat": 60.2, "lon": 24.8 }
                      ]
                    },
                    {
                      "stops": [
                        { "gtfsId": "HSL:STOP1", "name": "Stop 1", "lat": 60.1, "lon": 24.9 }
                      ]
                    }
                  ]
                }
              }
            }
            """.data(using: .utf8)
            return (response, data)
        }

        let stops = try await service.fetchStops(routeId: "HSL:123")
        let ids = Set(stops.map(\.id))
        #expect(ids == ["HSL:STOP1", "HSL:STOP2"])
        #expect(stops.count == 2)
    }

    @Test
    func fetchDeparturesMapsToDepartures() async throws {
        let (service, _) = makeService()

        let now = Int(Date().timeIntervalSince1970)
        let serviceDay = now - (now % 86_400)
        let realtimeDeparture = (now - serviceDay) + 300

        DigitransitServiceTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "stop": {
                  "stoptimesWithoutPatterns": [
                    {
                      "scheduledDeparture": \(realtimeDeparture),
                      "realtimeDeparture": \(realtimeDeparture),
                      "serviceDay": \(serviceDay),
                      "headsign": "Destination",
                      "pickupType": "SCHEDULED",
                      "stop": { "platformCode": "1" },
                      "trip": { "route": { "shortName": "550", "gtfsId": "HSL:550" } }
                    }
                  ]
                }
              }
            }
            """.data(using: .utf8)
            return (response, data)
        }

        let departures = try await service.fetchDepartures(request: .stop(stationId: "HSL:STOP1"))
        #expect(departures.count == 1)
        #expect(departures.first?.lineName == "550")
        #expect(departures.first?.platform == "1")
        #expect(departures.first?.headsign == "Destination")
    }

    @Test
    func addsAuthHeader() async throws {
        let (service, apiKey) = makeService()

        DigitransitServiceTestURLProtocol.requestHandler = { request in
            #expect(request.value(forHTTPHeaderField: "digitransit-subscription-key") == apiKey)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            { "data": { "routes": [] } }
            """.data(using: .utf8)
            return (response, data)
        }

        _ = try await service.searchRoutes(query: "x", transportMode: .bus)
    }

    @Test
    func departuresRequestEncodesTypedVariables() async throws {
        let (service, _) = makeService()
        let stationId = "HSL:STOP1"

        DigitransitServiceTestURLProtocol.requestHandler = { request in
            let body = try requestBodyData(request)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let variables = try #require(json["variables"] as? [String: Any])
            #expect(variables["stationId"] as? String == stationId)
            #expect(variables["count"] as? Int == MapConstants.departuresFetchCount)

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "stop": {
                  "stoptimesWithoutPatterns": []
                }
              }
            }
            """.data(using: .utf8)
            return (response, data)
        }

        _ = try await service.fetchDepartures(request: .stop(stationId: stationId))
    }

    @Test
    func apiErrorThrows() async {
        let (service, _) = makeService()

        DigitransitServiceTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await #expect(throws: AppError.self) {
            _ = try await service.fetchStops(routeId: "HSL:123")
        }
    }

    private func makeService() -> (DigitransitService, String) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DigitransitServiceTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let apiKey = "TEST_KEY"
        let service = DigitransitService(urlSession: session, digitransitKey: apiKey)
        return (service, apiKey)
    }
}
