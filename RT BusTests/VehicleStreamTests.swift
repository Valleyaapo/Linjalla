//
//  VehicleStreamTests.swift
//  RT BusTests
//
//  Subscription and buffering regression tests
//

import Testing
@testable import RT_Bus

@MainActor
@Suite("VehicleStream")
struct VehicleStreamTests {
    @Test("Builds HFP subscriptions for route id and HSL-prefixed id")
    func buildsSubscriptionsForRouteVariants() async {
        let stream = VehicleStream()
        let selections = [
            RouteSelection(id: "HSL:1065", routeId: "1065"),
            RouteSelection(id: "HSL:1004", routeId: "1004")
        ]

        let change = await stream.subscriptionChange(selections: selections, topicPrefix: "bus")

        #expect(change.newTopics.contains("/hfp/v2/journey/ongoing/vp/bus/+/+/1065/#"))
        #expect(change.newTopics.contains("/hfp/v2/journey/ongoing/vp/bus/+/+/+/1065/#"))
        #expect(change.newTopics.contains("/hfp/v2/journey/ongoing/vp/bus/+/+/HSL:1065/#"))
        #expect(change.newTopics.contains("/hfp/v2/journey/ongoing/vp/bus/+/+/+/HSL:1065/#"))

        #expect(change.newTopics.contains("/hfp/v2/journey/ongoing/vp/bus/+/+/1004/#"))
        #expect(change.newTopics.contains("/hfp/v2/journey/ongoing/vp/bus/+/+/+/1004/#"))
        #expect(change.newTopics.contains("/hfp/v2/journey/ongoing/vp/bus/+/+/HSL:1004/#"))
        #expect(change.newTopics.contains("/hfp/v2/journey/ongoing/vp/bus/+/+/+/HSL:1004/#"))
    }

    @Test("Rejects stale subscription updates")
    func rejectsStaleSubscriptionUpdates() async {
        let stream = VehicleStream()
        let selections = [RouteSelection(id: "HSL:1065", routeId: "1065")]

        let change1 = await stream.subscriptionChange(selections: selections, topicPrefix: "bus")
        #expect(await stream.applySubscriptionUpdate(requestId: change1.requestId, newTopics: change1.newTopics))

        let change2 = await stream.subscriptionChange(selections: [], topicPrefix: "bus")
        #expect(await stream.applySubscriptionUpdate(requestId: change2.requestId, newTopics: change2.newTopics))

        let appliedStale = await stream.applySubscriptionUpdate(requestId: change1.requestId, newTopics: change1.newTopics)
        #expect(!appliedStale)
    }

    @Test("Buffers and drains vehicle updates atomically")
    func bufferAndDrain() async {
        let stream = VehicleStream()
        let first = BusModel(
            id: 1,
            lineName: "1",
            routeId: "HSL:1001",
            latitude: 60.17,
            longitude: 24.94,
            heading: 0,
            timestamp: 100,
            type: .bus
        )
        let second = BusModel(
            id: 2,
            lineName: "2",
            routeId: "HSL:1002",
            latitude: 60.18,
            longitude: 24.95,
            heading: 90,
            timestamp: 200,
            type: .bus
        )

        await stream.buffer(first)
        await stream.buffer(second)

        let drained = await stream.drain()
        #expect(drained.count == 2)
        #expect(drained[1] == first)
        #expect(drained[2] == second)

        let empty = await stream.drain()
        #expect(empty.isEmpty)
    }
}
