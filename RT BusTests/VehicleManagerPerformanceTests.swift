import Testing
import Foundation
@testable import RT_Bus

@MainActor
@Suite("VehicleManagerPerformance")
struct VehicleManagerPerformanceTests {
    @Test("Process Message Throughput")
    func processMessageThroughput() async throws {
        let manager = BaseVehicleManager(connectOnStart: false)
        manager.vehicleUpdateBufferLimit = 10_000
        manager.setup()
        // Ensure stream is drained
        _ = await manager.stream.drain()

        let iterations = 10_000
        var payloads: [Data] = []
        let batchSize = 200

        // Pre-generate payloads
        for i in 0..<iterations {
             let json = """
             {"VP":{"veh":\(i),"desi":"10","lat":60.1,"long":24.9,"hdg":100,"tsi":1234567890}}
             """
             payloads.append(json.data(using: .utf8)!)
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(20))
        var processedCount = 0
        let elapsed = await clock.measure {
            for chunkStart in stride(from: 0, to: payloads.count, by: batchSize) {
                let chunkEnd = min(chunkStart + batchSize, payloads.count)
                for payload in payloads[chunkStart..<chunkEnd] {
                    await manager.processMessage(topicName: "/hfp/v2/journey/ongoing/vp/bus/HSL/1/10/1001/1", payload: payload)
                }
                await Task.yield()
                let drained = await manager.stream.drain()
                processedCount += drained.count
            }

            while processedCount < iterations && clock.now < deadline {
                await Task.yield()
                // Small sleep to allow async tasks to complete
                try? await Task.sleep(for: .milliseconds(10))

                let drained = await manager.stream.drain()
                processedCount += drained.count
            }
        }
        #expect(processedCount == iterations)
        #expect(elapsed < .seconds(10))
    }
}
