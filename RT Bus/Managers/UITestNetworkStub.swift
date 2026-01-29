//
//  UITestNetworkStub.swift
//  RT Bus
//

import Foundation

enum UITestNetworkStub {
    private static var isRegistered = false

    static func registerIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("UITesting") else { return }
        guard !isRegistered else { return }
        URLProtocol.registerClass(UITestURLProtocol.self)
        isRegistered = true
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class UITestURLProtocol: URLProtocol {
    override class func canInit(with task: URLSessionTask) -> Bool {
        guard let request = task.currentRequest ?? task.originalRequest else { return false }
        return canInit(with: request)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard ProcessInfo.processInfo.arguments.contains("UITesting") else { return false }
        guard let host = request.url?.host else { return false }
        return host == "api.digitransit.fi" || host == "rata.digitraffic.fi"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override func startLoading() {
        guard let url = request.url else { return }
        let (statusCode, data) = stubResponse(for: request)
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func stubResponse(for request: URLRequest) -> (Int, Data?) {
        guard let host = request.url?.host else {
            return (404, Data())
        }
        switch host {
        case "api.digitransit.fi":
            return stubDigitransit(request)
        case "rata.digitraffic.fi":
            return stubDigitraffic(request)
        default:
            return (404, Data())
        }
    }

    private func stubDigitransit(_ request: URLRequest) -> (Int, Data?) {
        let body = requestBodyData(request)
        let query = body.flatMap { jsonQuery(from: $0) } ?? ""

        if query.contains("SearchRoutes") || query.contains("routes(name") {
            let data = """
            { "data": { "routes": [ { "gtfsId": "HSL:2550", "shortName": "550", "longName": "Test Line" } ] } }
            """.data(using: .utf8)
            return (200, data)
        }

        if query.contains("GetRouteStops") || query.contains("route(id") {
            let data = """
            { "data": { "route": { "patterns": [ { "stops": [ { "gtfsId": "HSL:STOP1", "name": "Mock Stop", "lat": 60.1701, "lon": 24.9415 } ] } ] } } }
            """.data(using: .utf8)
            return (200, data)
        }

        if query.contains("GetStationDepartures") || query.contains("station(id") {
            let data = departuresResponseJSON()
            return (200, data)
        }

        if query.contains("GetDepartures") || query.contains("stop(id") {
            let data = departuresResponseJSON()
            return (200, data)
        }

        let data = "{ \"data\": {} }".data(using: .utf8)
        return (200, data)
    }

    private func departuresResponseJSON() -> Data? {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let serviceDay = Int(startOfDay.timeIntervalSince1970)
        let secondsSinceMidnight = Int(now.timeIntervalSince1970) - serviceDay
        let departure = secondsSinceMidnight + 300

        let json = """
        {
          "data": {
            "stop": {
              "stoptimesWithoutPatterns": [
                {
                  "scheduledDeparture": \(departure),
                  "realtimeDeparture": \(departure),
                  "serviceDay": \(serviceDay),
                  "headsign": "Rautatientori",
                  "pickupType": "SCHEDULED",
                  "stop": { "platformCode": "1" },
                  "trip": { "route": { "gtfsId": "HSL:2550", "shortName": "550" } }
                }
              ]
            },
            "station": {
              "stoptimesWithoutPatterns": [
                {
                  "scheduledDeparture": \(departure),
                  "realtimeDeparture": \(departure),
                  "serviceDay": \(serviceDay),
                  "headsign": "Rautatientori",
                  "pickupType": "SCHEDULED",
                  "stop": { "platformCode": "1" },
                  "trip": { "route": { "gtfsId": "HSL:2550", "shortName": "550" } }
                }
              ]
            }
          }
        }
        """
        return json.data(using: .utf8)
    }

    private func stubDigitraffic(_ request: URLRequest) -> (Int, Data?) {
        guard let url = request.url else {
            return (404, Data())
        }
        if url.path.contains("/metadata/stations") {
            let data = """
            [
              { "stationName": "Helsinki asema", "stationShortCode": "HKI" }
            ]
            """.data(using: .utf8)
            return (200, data)
        }

        if url.path.contains("/live-trains/station/HKI") {
            let now = Date()
            let formatter = ISO8601DateFormatter()
            let scheduled = formatter.string(from: now.addingTimeInterval(300))
            let arrival = formatter.string(from: now.addingTimeInterval(1800))
            let data = """
            [
              {
                "trainNumber": 1,
                "trainCategory": "Commuter",
                "commuterLineID": "I",
                "timeTableRows": [
                  {
                    "stationShortCode": "HKI",
                    "type": "DEPARTURE",
                    "scheduledTime": "\(scheduled)",
                    "liveEstimateTime": "\(scheduled)",
                    "commercialTrack": "1",
                    "commercialStop": true,
                    "trainStopping": true
                  },
                  {
                    "stationShortCode": "TIK",
                    "type": "ARRIVAL",
                    "scheduledTime": "\(arrival)",
                    "liveEstimateTime": null,
                    "commercialTrack": "2",
                    "commercialStop": true,
                    "trainStopping": true
                  }
                ]
              }
            ]
            """.data(using: .utf8)
            return (200, data)
        }

        return (404, Data())
    }

    private func requestBodyData(_ request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let readCount = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
                guard let base = rawBuffer.baseAddress else { return -1 }
                return stream.read(base.assumingMemoryBound(to: UInt8.self), maxLength: rawBuffer.count)
            }
            if readCount <= 0 {
                break
            }
            data.append(buffer, count: readCount)
        }
        return data
    }

    private func jsonQuery(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? String else {
            return nil
        }
        return query
    }
}
