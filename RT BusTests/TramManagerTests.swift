//
//  TramManagerTests.swift
//  RTBusTests
//
//  Created by Automation on 10.01.2026.
//

import Testing
import Foundation
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct TramManagerTests {
    
    @Test
    func searchLinesFailure() async throws {
        // Setup
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let tramManager = TramManager(urlSession: session, connectOnStart: false)
        
        // Mock
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            { "data": { "routes": [] } }
            """.data(using: .utf8)
            return (response, data)
        }
        
        // Test
        let lines = try await tramManager.searchLines(query: "invalid")
        #expect(lines.isEmpty)
    }

    @Test
    func searchLinesSuccess() async throws {
        // Setup
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let tramManager = TramManager(urlSession: session, connectOnStart: false)
        
        // Mock
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "routes": [
                  { "gtfsId": "HSL:123", "shortName": "4", "longName": "Test Tram" }
                ]
              }
            }
            """.data(using: .utf8)
            return (response, data)
        }
        
        // Test
        let lines = try await tramManager.searchLines(query: "4")
        #expect(lines.count == 1)
        #expect(lines.first?.shortName == "4")
        #expect(lines.first?.longName == "Test Tram")
        #expect(lines.first?.id == "HSL:123")
    }
    
    @Test
    func searchLinesApiError() async throws {
        // Setup
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let tramManager = TramManager(urlSession: session, connectOnStart: false)
        
        // Mock 500 Error
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        // Test
        await #expect(throws: AppError.self) {
            _ = try await tramManager.searchLines(query: "error")
        }
        
        if case .apiError(let msg) = tramManager.error {
            #expect(msg == "Tram Search Failed" || msg == "HTTP 500")
        } else if case .networkError(let msg) = tramManager.error {
             #expect(msg == "Tram Search Failed")
        } else {
            #expect(tramManager.error != nil, "tramManager.error was nil")
        }
    }

    @Test
    func favorites() {
        let tramManager = TramManager(connectOnStart: false)
        let line = BusLine(id: "HSL:444", shortName: "4", longName: "Favorite Tram")
        
        // Ensure not favorite initially
        #expect(!tramManager.favoriteLines.contains(where: { $0.id == line.id }))
        
        // Toggle On
        tramManager.toggleFavorite(line)
        #expect(tramManager.favoriteLines.contains(where: { $0.id == line.id }))
        
        // Toggle Off
        tramManager.toggleFavorite(line)
        #expect(!tramManager.favoriteLines.contains(where: { $0.id == line.id }))
    }
}
