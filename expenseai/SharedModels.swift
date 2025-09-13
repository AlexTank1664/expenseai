import Foundation

struct AppError: Identifiable, Error {
    let id = UUID()
    let message: String
    
    // Conformance to LocalizedError
    var errorDescription: String? {
        return message
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let auth_token: String
}

struct RegistrationRequest: Codable {
    let first_name: String
    let last_name: String
    let email: String
    let password: String
    let password2: String
}

// Djoser (популярная библиотека для Django) обычно возвращает созданного пользователя
struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let first_name: String
    let last_name: String
}