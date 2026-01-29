//
//  DepartureFilteringTests.swift
//  RT BusTests
//

import Testing
import Foundation
@testable import RTBusCore

@MainActor
@Suite(.serialized)
struct DepartureFilteringTests {

    @Test
    func excludesPastDeparturesByDefault() {
        let now: TimeInterval = 1_000
        let past = makeDeparture(lineName: "550", routeId: "HSL:550", realtimeTime: 900)
        let future = makeDeparture(lineName: "550", routeId: "HSL:550", realtimeTime: 1_100)

        let result = DepartureFiltering.apply([past, future], filter: nil, now: now)
        #expect(result.count == 1)
        #expect(result.first?.realtimeTime == 1_100)
    }

    @Test
    func includesPastWhenRequested() {
        let now: TimeInterval = 1_000
        let past = makeDeparture(lineName: "550", routeId: "HSL:550", realtimeTime: 900)
        let future = makeDeparture(lineName: "550", routeId: "HSL:550", realtimeTime: 1_100)

        let filter = DepartureFilterInput(routeIds: [], lineNames: [], includePast: true)
        let result = DepartureFiltering.apply([past, future], filter: filter, now: now)
        #expect(result.count == 2)
    }

    @Test
    func matchesRouteIdNormalization() {
        let departure = makeDeparture(lineName: "550", routeId: "HSL:550", realtimeTime: 1_100)
        let filter = DepartureFilterInput(routeIds: [], lineNames: ["550"], includePast: true)

        let result = DepartureFiltering.apply([departure], filter: filter, now: 0)
        #expect(result.count == 1)
    }

    @Test
    func matchesRouteIdSuffixes() {
        let departure = makeDeparture(lineName: "550", routeId: "HSL:550", realtimeTime: 1_100)
        let filter = DepartureFilterInput(routeIds: ["HSL:550N"], lineNames: [], includePast: true)

        let result = DepartureFiltering.apply([departure], filter: filter, now: 0)
        #expect(result.count == 1)
    }

    private func makeDeparture(
        lineName: String,
        routeId: String?,
        realtimeTime: Int
    ) -> Departure {
        Departure(
            lineName: lineName,
            routeId: routeId,
            headsign: "Test",
            scheduledTime: realtimeTime,
            realtimeTime: realtimeTime,
            serviceDay: 0,
            platform: nil
        )
    }
}
