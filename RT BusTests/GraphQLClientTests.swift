//
//  GraphQLClientTests.swift
//  RT BusTests
//

import Testing
import Foundation
@testable import RTBusCore

@MainActor
@Suite(.serialized)
struct GraphQLClientTests {
    final class GraphQLClientTestURLProtocol: URLProtocol {
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
    func graphQLErrorsThrowApiError() async {
        let client = makeClient()
        GraphQLClientTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            { "errors": [ { "message": "Boom" } ] }
            """.data(using: .utf8)
            return (response, data)
        }

        await #expect(throws: AppError.self) {
            let _: GraphQLStopResponse = try await client.request(
                query: "query",
                variables: RouteStopsVars(id: "HSL:123"),
                as: GraphQLStopResponse.self
            )
        }
    }

    @Test
    func httpStatusMapsToApiError() async {
        let client = makeClient()
        GraphQLClientTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            let data = """
            { "data": { "routes": [] } }
            """.data(using: .utf8)
            return (response, data)
        }

        await #expect(throws: AppError.self) {
            let _: GraphQLRouteResponse = try await client.request(
                query: "query",
                variables: SearchRoutesVars(name: "x"),
                as: GraphQLRouteResponse.self
            )
        }
    }

    @Test
    func offlineURLErrorPassesThrough() async {
        let client = makeClient()
        GraphQLClientTestURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            let _: GraphQLRouteResponse = try await client.request(
                query: "query",
                variables: SearchRoutesVars(name: "x"),
                as: GraphQLRouteResponse.self
            )
            Issue.record("Expected offline error")
        } catch {
            let urlError = error as? URLError
            #expect(urlError != nil)
            #expect(urlError?.code == .notConnectedToInternet)
        }
    }

    private func makeClient() -> GraphQLClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GraphQLClientTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return GraphQLClient(
            session: session,
            apiKey: "test",
            endpoint: "https://example.com/graphql"
        )
    }
}
