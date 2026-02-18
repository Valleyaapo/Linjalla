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
    private let retryPolicy: RetryPolicy

    init(session: URLSession, apiKey: String, endpoint: String) {
        self.session = session
        self.apiKey = apiKey
        self.retryPolicy = .default
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
        let urlRequest = try makeRequest(query: query, variables: variables)
        var lastError: Error?

        for attempt in 0..<retryPolicy.maxAttempts {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.networkError("Invalid Response")
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw ClientError.httpStatus(httpResponse.statusCode)
                }

                try throwIfGraphQLErrors(in: data)

                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)

            } catch {
                lastError = error

                if error is CancellationError {
                    throw error
                }

                let isLastAttempt = attempt >= retryPolicy.maxAttempts - 1
                if isLastAttempt || !shouldRetry(error: error) {
                    throw mapError(error)
                }

                let delayTime = retryPolicy.delay(for: attempt)
                Logger.digitransit.warning("Retrying request in \(delayTime, format: .fixed(precision: 2))s (attempt \(attempt + 2)/\(self.retryPolicy.maxAttempts))")
                try await Task.sleep(for: .seconds(delayTime))
            }
        }

        throw mapError(lastError ?? AppError.networkError("Request failed after retries"))
    }

    private func makeRequest<V: Encodable & Sendable>(query: String, variables: V) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "digitransit-subscription-key")
        do {
            let encoder = JSONEncoder()
            let body = RequestBody(query: query, variables: variables)
            request.httpBody = try encoder.encode(body)
        } catch {
            // Security: Use default privacy (private) for error details to prevent PII leakage
            Logger.digitransit.error("GraphQL encode failed error=\(String(describing: error))")
            throw AppError.networkError(error.localizedDescription)
        }
        return request
    }

    private func throwIfGraphQLErrors(in data: Data) throws {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(ErrorProbe.self, from: data),
              let errors = probe.errors,
              !errors.isEmpty else {
            return
        }
        let message = errors.map(\.message).joined(separator: "\n")
        // Security: Use default privacy (private) for error details to prevent PII leakage
        Logger.digitransit.error("GraphQL errors: \(message)")
        throw AppError.apiError(message)
    }

    private func shouldRetry(error: Error) -> Bool {
        if RetryPolicy.isRetryable(error) {
            return true
        }
        if let clientError = error as? ClientError,
           case .httpStatus(let code) = clientError,
           RetryPolicy.isRetryableStatus(code) {
            return true
        }
        if case AppError.networkError = error {
            return true
        }
        return false
    }

    private func mapError(_ error: Error) -> Error {
        if let appError = error as? AppError {
            return appError
        }
        if let clientError = error as? ClientError {
            switch clientError {
            case .httpStatus(let statusCode):
                return AppError.apiError("HTTP \(statusCode)")
            }
        }
        return NetworkErrorMapper.map(error)
    }
}
