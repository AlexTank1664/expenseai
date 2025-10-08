import Foundation

/// Кастомные ошибки для более удобной отладки и обработки.
enum SyncError: Error, LocalizedError {
    case networkError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case unknownError(Error)
    case coreDataError(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .networkError(let statusCode, _):
            return "Network error: Status code: \(statusCode)"
        case .decodingError(let error):
            return "Decode error: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .coreDataError(let message):
            return "Core Data error: \(message)"
        case .notAuthenticated:
            return "Authorization error during synchronization process."
        }
    }
}
