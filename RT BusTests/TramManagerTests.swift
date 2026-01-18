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

    final class TramManagerTestURLProtocol: URLProtocol {
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
    func searchLinesFailure() async throws {
        // Setup
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TramManagerTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let tramManager = TramManager(urlSession: session, connectOnStart: false)
        
        // Mock
        TramManagerTestURLProtocol.requestHandler = { request in
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
        configuration.protocolClasses = [TramManagerTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let tramManager = TramManager(urlSession: session, connectOnStart: false)
        
        // Mock
        TramManagerTestURLProtocol.requestHandler = { request in
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
        configuration.protocolClasses = [TramManagerTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let tramManager = TramManager(urlSession: session, connectOnStart: false)
        
        // Mock 500 Error
        TramManagerTestURLProtocol.requestHandler = { request in
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
