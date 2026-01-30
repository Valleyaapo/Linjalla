//
//  NetworkService.swift
//  RT Bus
//
//  Created by Aapo Laakso on 01.01.2026.
//

import Foundation
import OSLog

public actor NetworkService {
    public static let shared = NetworkService()

    private let session: URLSession
    private let retryPolicy: RetryPolicy
    private static let defaultDecoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        self.retryPolicy = .default
    }

    public func fetch<T: Decodable>(
        _ request: URLRequest,
        decoder: JSONDecoder? = nil
    ) async throws -> T {
        let jsonDecoder = decoder ?? Self.defaultDecoder
        var lastError: Error?

        for attempt in 0..<retryPolicy.maxAttempts {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw AppError.apiError("HTTP \(httpResponse.statusCode)")
                    }
                }

                return try jsonDecoder.decode(T.self, from: data)

            } catch {
                lastError = error

                if error is CancellationError {
                    throw error
                }

                let isLastAttempt = attempt >= retryPolicy.maxAttempts - 1
                let shouldRetry = RetryPolicy.isRetryable(error) || isRetryableAPIError(error)

                if isLastAttempt || !shouldRetry {
                    throw mapError(error)
                }

                let delayTime = retryPolicy.delay(for: attempt)
                Logger.network.warning("Retrying request in \(delayTime, format: .fixed(precision: 2))s (attempt \(attempt + 2)/\(self.retryPolicy.maxAttempts))")
                try await Task.sleep(for: .seconds(delayTime))
            }
        }

        throw mapError(lastError ?? AppError.networkError("Request failed after retries"))
    }

    private func isRetryableAPIError(_ error: Error) -> Bool {
        if case AppError.apiError(let msg) = error,
           let code = Int(msg.replacingOccurrences(of: "HTTP ", with: "")) {
            return RetryPolicy.isRetryableStatus(code)
        }
        return false
    }

    private func mapError(_ error: Error) -> Error {
        NetworkErrorMapper.map(error)
    }
}
