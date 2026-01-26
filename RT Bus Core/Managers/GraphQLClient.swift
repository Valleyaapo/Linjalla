import Foundation
import OSLog

actor GraphQLClient {
    private struct RequestBody<V: Encodable & Sendable>: Encodable {
        let query: String
        let variables: V
    }

    private struct ErrorProbe: Decodable {
        let errors: [GraphQLError]?
    }

    private struct GraphQLError: Decodable {
        let message: String
    }

    private enum ClientError: Error {
        case httpStatus(Int)
    }

    private let session: URLSession
    private let apiKey: String
    private let endpoint: URL
    private let maxRetries = 3

    init(session: URLSession, apiKey: String, endpoint: String) {
        self.session = session
        self.apiKey = apiKey
        guard let url = URL(string: endpoint) else {
            preconditionFailure("Invalid GraphQL endpoint")
        }
        self.endpoint = url
    }

    func request<V: Encodable & Sendable, T: Decodable & Sendable>(
        query: String,
        variables: V,
        as type: T.Type
    ) async throws -> T {
        let request = try makeRequest(query: query, variables: variables)
        let data = try await perform(request: request)
        try throwIfGraphQLErrors(in: data)
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(T.self, from: data)
            return result
        } catch {
            Logger.network.error("Decoding error: \(error)")
            throw AppError.decodingError(error.localizedDescription)
        }
    }

    private func makeRequest<V: Encodable & Sendable>(query: String, variables: V) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "digitransit-subscription-key")
        do {
            let encoder = JSONEncoder()
            let body = RequestBody(query: query, variables: variables)
            let encoded = try encoder.encode(body)
            request.httpBody = encoded
        } catch {
            Logger.digitransit.error("GraphQL encode failed error=\(String(describing: error), privacy: .public)")
            throw AppError.networkError(error.localizedDescription)
        }

        return request
    }

    private func perform(request: URLRequest) async throws -> Data {
        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetries {
            try Task.checkCancellation()
            do {
            let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.networkError("Invalid Response")
                }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw ClientError.httpStatus(httpResponse.statusCode)
            }
            return data
            } catch {
                lastError = error
                if error is CancellationError {
                    throw error
                }
                Logger.digitransit.error("HTTP attempt failed attempt=\(attempt) error=\(String(describing: error), privacy: .public)")

                guard attempt < maxRetries, shouldRetry(error: error) else {
                    throw mapError(error)
                }

                let delay = retryDelay(for: attempt)
                Logger.network.warning("Retrying Digitransit request in \(delay, format: .fixed(precision: 2))s (attempt \(attempt + 1))")
                try await Task.sleep(for: .seconds(delay))
                attempt += 1
            }
        }

        throw mapError(lastError ?? AppError.networkError("Unknown error"))
    }

    private func throwIfGraphQLErrors(in data: Data) throws {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(ErrorProbe.self, from: data),
              let errors = probe.errors,
              !errors.isEmpty else {
            return
        }
        let message = errors.map(\.message).joined(separator: "\n")
        Logger.digitransit.error("GraphQL errors: \(message, privacy: .public)")
        throw AppError.apiError(message)
    }

    private func shouldRetry(error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .networkConnectionLost,
                .notConnectedToInternet,
                .timedOut,
                .cannotConnectToHost,
                .cannotFindHost
            ].contains(urlError.code)
        }

        if let clientError = error as? ClientError {
            switch clientError {
            case .httpStatus(let statusCode):
                return statusCode == 429 || (500...599).contains(statusCode)
            }
        }

        if case AppError.networkError = error {
            return true
        }

        return false
    }

    private func retryDelay(for attempt: Int) -> TimeInterval {
        let base: TimeInterval = 0.5
        let maxDelay: TimeInterval = 6.0
        let exponential = base * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5)
        return min(maxDelay, exponential + jitter)
    }

    private func mapError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        if let urlError = error as? URLError {
            return AppError.networkError(urlError.localizedDescription)
        }
        if let clientError = error as? ClientError {
            switch clientError {
            case .httpStatus(let statusCode):
                return AppError.apiError("HTTP \(statusCode)")
            }
        }
        return AppError.networkError(error.localizedDescription)
    }
}
