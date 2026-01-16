//
//  StopManagerTests.swift
//  RTBusTests
//
//  Created by Automation on 01.01.2026.
//

import Testing
import Foundation
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct StopManagerTests {

    @Test
    func fetchDepartures() async throws {
        // Setup
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let stopManager = StopManager(urlSession: session)
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "stop": {
                  "stoptimesWithoutPatterns": [
                    {
                      "scheduledDeparture": 40000,
                      "realtimeDeparture": 40100,
                      "serviceDay": 1600000000,
                      "headsign": "Destination",
                      "pickupType": "SCHEDULED",
                      "stop": { "platformCode": "1" },
                      "trip": { "route": { "shortName": "550" } }
                    }
                  ]
                }
             }
            }
            """.data(using: .utf8)
            return (response, data)
        }
        
        let departures = try await stopManager.fetchDepartures(for: "HSL:TEST")
        #expect(departures.count == 1)
        #expect(departures.first?.lineName == "550")
        #expect(departures.first?.platform == "1")
    }
    
    @Test
    func fetchDeparturesEmpty() async throws {
         // Setup
         let configuration = URLSessionConfiguration.ephemeral
         configuration.protocolClasses = [MockURLProtocol.self]
         let session = URLSession(configuration: configuration)
         let stopManager = StopManager(urlSession: session)

         MockURLProtocol.requestHandler = { request in
             let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
             let data = """
             { "data": { "stop": { "stoptimesWithoutPatterns": [] } } }
             """.data(using: .utf8)
             return (response, data)
         }
         
         let departures = try await stopManager.fetchDepartures(for: "HSL:TEST")
         #expect(departures.isEmpty)
     }
}
