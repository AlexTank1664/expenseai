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
            return "Ошибка сети: Статус-код \(statusCode)"
        case .decodingError(let error):
            return "Ошибка декодирования: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        case .coreDataError(let message):
            return "Ошибка Core Data: \(message)"
        case .notAuthenticated:
            return "Пользователь не аутентифицирован."
        }
    }
}