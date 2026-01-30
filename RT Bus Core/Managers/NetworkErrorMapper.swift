//
//  NetworkErrorMapper.swift
//  RT Bus Core
//
//  Created by Codex on 31.01.2026.
//

import Foundation

public enum NetworkErrorMapper {
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .cannotLoadFromNetwork,
        .internationalRoamingOff
    ]

    public static func isOffline(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain,
               let code = URLError.Code(rawValue: nsError.code) {
                return offlineCodes.contains(code)
            }
            return false
        }
        return offlineCodes.contains(urlError.code)
    }

    static func map(_ error: Error) -> Error {
        if let appError = error as? AppError {
            return appError
        }
        if let urlError = error as? URLError {
            return map(urlError)
        }
        if error is DecodingError {
            return AppError.decodingError(error.localizedDescription)
        }
        return AppError.networkError(error.localizedDescription)
    }

    private static func map(_ error: URLError) -> Error {
        if offlineCodes.contains(error.code) {
            return error
        }
        return AppError.networkError(error.localizedDescription)
    }
}
