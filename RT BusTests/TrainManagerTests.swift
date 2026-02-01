//
//  TrainManagerTests.swift
//  RTBusTests
//
//  Created by Automation on 31.01.2026.
//

import Testing
import Foundation
import RTBusCore
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct TrainManagerTests {

    @Test
    func processTrainRejectsNonCommuter() async throws {
        let manager = TrainManager()
        let now = Date()
        let rows = [makeRow(station: "HKI", type: "DEPARTURE", time: now.addingTimeInterval(120))]
        let train = DigitrafficTrain(trainNumber: 1, trainCategory: "Long-distance", commuterLineID: nil, timeTableRows: rows)

        #expect(manager.processTrain(train, for: "HKI", at: now) == nil)
    }

    @Test
    func processTrainRejectsPastDeparture() async throws {
        let manager = TrainManager()
        let now = Date()
        let rows = [makeRow(station: "HKI", type: "DEPARTURE", time: now.addingTimeInterval(-120))]
        let train = DigitrafficTrain(trainNumber: 1, trainCategory: "Commuter", commuterLineID: "I", timeTableRows: rows)

        #expect(manager.processTrain(train, for: "HKI", at: now) == nil)
    }

    @Test
    func processTrainRejectsLastRowDeparture() async throws {
        let manager = TrainManager()
        let now = Date()
        let rows = [makeRow(station: "HKI", type: "DEPARTURE", time: now.addingTimeInterval(120))]
        let train = DigitrafficTrain(trainNumber: 1, trainCategory: "Commuter", commuterLineID: "I", timeTableRows: rows)

        #expect(manager.processTrain(train, for: "HKI", at: now) == nil)
    }

    @Test
    func processTrainRingRailHeadsign() async throws {
        let manager = TrainManager()
        manager.stationNames = ["HKI": "Helsinki"]
        let now = Date()
        let rows = [
            makeRow(station: "HKI", type: "DEPARTURE", time: now.addingTimeInterval(120), track: "5"),
            makeRow(station: "HKI", type: "ARRIVAL", time: now.addingTimeInterval(900), track: nil)
        ]
        let train = DigitrafficTrain(trainNumber: 1, trainCategory: "Commuter", commuterLineID: "I", timeTableRows: rows)

        let departure = manager.processTrain(train, for: "HKI", at: now)
        #expect(departure?.headsign == "via Tikkurila")
        #expect(departure?.platform == "5")
    }
}

private func makeRow(
    station: String,
    type: String,
    time: Date,
    commercialStop: Bool = true,
    track: String? = "1"
) -> DigitrafficTimeTableRow {
    DigitrafficTimeTableRow(
        stationShortCode: station,
        type: type,
        scheduledTime: time,
        liveEstimateTime: nil,
        commercialTrack: track,
        commercialStop: commercialStop,
        trainStopping: nil
    )
}
