//
//  RetryPolicy.swift
//  RT Bus Core
//

import Foundation

/// Shared retry policy configuration for network requests.
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let useJitter: Bool

    public static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 0.5,
        maxDelay: 6.0,
        useJitter: true
    )

    public init(maxAttempts: Int, baseDelay: TimeInterval, maxDelay: TimeInterval, useJitter: Bool) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.useJitter = useJitter
    }

    /// Calculate delay for a given attempt (0-indexed).
    public func delay(for attempt: Int) -> TimeInterval {
        let exponential = baseDelay * pow(2.0, Double(attempt))
        let jitter = useJitter ? Double.random(in: 0...0.5) : 0
        return min(maxDelay, exponential + jitter)
    }

    /// Determine if an error is retryable based on URL error codes.
    public static func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .networkConnectionLost,
                .notConnectedToInternet,
                .timedOut,
                .cannotConnectToHost,
                .cannotFindHost
            ].contains(urlError.code)
        }
        return false
    }

    /// Determine if an HTTP status code is retryable.
    public static func isRetryableStatus(_ statusCode: Int) -> Bool {
        statusCode == 429 || (500...599).contains(statusCode)
    }
}
