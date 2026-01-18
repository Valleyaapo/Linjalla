//
//  BusManagerTests.swift
//  RT BusTests
//
//  Created by Automation on 10.01.2026.
//

import Testing
import Foundation
import Combine
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct BusManagerTests {

    final class BusManagerTestURLProtocol: URLProtocol {
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
    func searchLinesSuccess() async throws {
        // Setup
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BusManagerTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let busManager = BusManager(urlSession: session, connectOnStart: false)
        
        // Mock
        BusManagerTestURLProtocol.requestHandler = { request in
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
        
        // Test
        let lines = try await busManager.searchLines(query: "123")
        #expect(lines.count == 1)
        #expect(lines.first?.shortName == "123")
        #expect(lines.first?.longName == "Test Line")
        #expect(lines.first?.id == "HSL:123")
    }
    
    @Test
    func searchLinesApiError() async throws {
        // Setup
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BusManagerTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let busManager = BusManager(urlSession: session, connectOnStart: false)
        
        // Mock 500 Error
        BusManagerTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        // Test
        await #expect(throws: AppError.self) {
            _ = try await busManager.searchLines(query: "99")
        }
        
        if case .apiError(let msg) = busManager.error {
            #expect(msg == "HTTP 500")
        } else {
             #expect(busManager.error != nil, "busManager.error was nil")
        }
    }
    
    @Test
    func favorites() {
        let busManager = BusManager(connectOnStart: false)
        let line = BusLine(id: "HSL:Test", shortName: "99", longName: "Test Line")
        
        // Ensure not favorite
        #expect(!busManager.favoriteLines.contains(where: { $0.id == line.id }))
        
        // Toggle On
        busManager.toggleFavorite(line)
        #expect(busManager.favoriteLines.contains(where: { $0.id == line.id }))
        
        // Toggle Off
        busManager.toggleFavorite(line)
        #expect(!busManager.favoriteLines.contains(where: { $0.id == line.id }))
    }
}
