//
//  TopicParsingTests.swift
//  RT BusTests
//
//  MQTT topic parsing regression tests
//

import Testing

@Suite("MQTT topic parsing")
struct TopicParsingTests {
    @Test("Route ID parsed from HFP topic segment 8")
    func routeIdParsedFromTopic() {
        let topic = "/hfp/v2/journey/ongoing/vp/bus/0018/01101/1065/1/Veräjälaakso/01:54/1020105/4/60;24/19/74/17"
        let parts = topic.split(separator: "/")
        let routeId = parts.count > 8 ? String(parts[8]) : nil
        #expect(routeId == "1065")
    }
}
