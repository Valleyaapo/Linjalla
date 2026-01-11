//
//  NetworkService.swift
//  RT Bus
//
//  Created by Refactor on 01.01.2026.
//

import Foundation
import OSLog

actor NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    func fetch<T: Decodable>(_ request: URLRequest, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let maxRetries = 3
        var currentAttempt = 0
        var lastError: Error?
        
        while currentAttempt <= maxRetries {
            do {
                if currentAttempt > 0 {
                    let delay = pow(2.0, Double(currentAttempt - 1)) * 0.5 // 0.5s, 1s, 2s
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    Logger.network.warning("Retrying request (attempt \(currentAttempt + 1))...")
                }
                
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw AppError.apiError("HTTP \(httpResponse.statusCode)")
                    }
                }
                
                return try decoder.decode(T.self, from: data)
                
            } catch {
                lastError = error
                
                // Identify retryable errors
                let nsError = error as NSError
                let isConnectivityError = [
                    NSURLErrorNetworkConnectionLost,
                    NSURLErrorNotConnectedToInternet,
                    NSURLErrorTimedOut,
                    NSURLErrorCannotConnectToHost
                ].contains(nsError.code)
                
                if isConnectivityError && currentAttempt < maxRetries {
                    currentAttempt += 1
                    continue
                }
                
                throw error
            }
        }
        
        throw lastError ?? AppError.networkError("Request failed after retries")
    }
}

