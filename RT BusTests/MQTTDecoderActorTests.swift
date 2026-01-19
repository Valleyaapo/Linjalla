//
//  MQTTDecoderActorTests.swift
//  RT BusTests
//

import Foundation
import Testing
@testable import RT_Bus

actor DecoderActor {
    private let decoder = JSONDecoder()

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}

private struct LocalVP: Decodable {
    let veh: Int
    let desi: String?
    let lat: Double?
    let long: Double?
    let hdg: Int?
    let tsi: TimeInterval?
}

private struct LocalResponse: Decodable {
    let VP: LocalVP
}

@Suite("MQTT decoder concurrency")
struct MQTTDecoderActorTests {
    @Test
    func decodesManyPayloadsInParallel() async {
        let decoder = DecoderActor()
        let stream = VehicleStream()
        let payloadCount = 200

        let payloads: [Data] = (1...payloadCount).map { id in
            let json = """
            {"VP":{"veh":\(id),"desi":"\(id)","lat":60.17,"long":24.94,"hdg":90,"tsi":\(id)}}
            """
            return Data(json.utf8)
        }

        await withTaskGroup(of: Void.self) { group in
            for data in payloads {
                group.addTask {
                    do {
                        let response = try await decoder.decode(LocalResponse.self, from: data)
                        let vp = response.VP
                        guard let lat = vp.lat, let long = vp.long, let desi = vp.desi else { return }
                        let vehicle = BusModel(
                            id: vp.veh,
                            lineName: desi,
                            routeId: "HSL:\(vp.veh)",
                            latitude: lat,
                            longitude: long,
                            heading: vp.hdg,
                            timestamp: vp.tsi ?? Date().timeIntervalSince1970,
                            type: .bus
                        )
                        await stream.buffer(vehicle)
                    } catch {
                        Issue.record("Decode failed: \(error)")
                    }
                }
            }
        }

        let drained = await stream.drain()
        let firstLineName = await MainActor.run { drained[1]?.lineName }
        let lastLineName = await MainActor.run { drained[payloadCount]?.lineName }

        #expect(drained.count == payloadCount)
        #expect(firstLineName == "1")
        #expect(lastLineName == "\(payloadCount)")
    }
}
