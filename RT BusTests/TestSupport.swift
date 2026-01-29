//
//  TestSupport.swift
//  RT BusTests
//

import Foundation
import Testing

func requestBodyData(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }

    let stream = try #require(request.httpBodyStream)
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
