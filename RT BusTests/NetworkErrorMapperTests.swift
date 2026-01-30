//
//  NetworkErrorMapperTests.swift
//  RT BusTests
//

import Testing
import Foundation
@testable import RTBusCore

@Suite(.serialized)
struct NetworkErrorMapperTests {
    @Test
    func offlineCodesAreDetected() {
        #expect(NetworkErrorMapper.isOffline(URLError(.notConnectedToInternet)))
        #expect(NetworkErrorMapper.isOffline(URLError(.networkConnectionLost)))
        #expect(NetworkErrorMapper.isOffline(URLError(.cannotConnectToHost)))
    }

    @Test
    func mapReturnsURLErrorForOffline() {
        let error = URLError(.notConnectedToInternet)
        let mapped = NetworkErrorMapper.map(error)
        let urlError = mapped as? URLError
        #expect(urlError != nil)
        #expect(urlError?.code == .notConnectedToInternet)
    }

    @Test
    func mapReturnsAppErrorForNonOffline() {
        let error = URLError(.timedOut)
        let mapped = NetworkErrorMapper.map(error)
        #expect(mapped is AppError)
    }
}
