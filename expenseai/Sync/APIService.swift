import Foundation

/// `APIService` инкапсулирует всю работу с сетью.
/// Использует Swift Concurrency (async/await) и дженерики для максимальной переиспользуемости.
final class APIService {
    
    // Синглтон для удобного доступа
    static let shared = APIService()
    
    // Создаем кастомный форматер, который умеет работать с долями секунд.
    // Делаем его static, чтобы он создавался только один раз.
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private let baseURL: URL
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    // Приватный инициализатор для синглтона
    private init() {
        guard let url = URL(string: APIConstants.baseURL) else {
            fatalError("Base URL is invalid")
        }
        self.baseURL = url
        
        self.session = URLSession(configuration: .default)
        
        // Настраиваем декодер для работы с датами в формате ISO 8601
        self.jsonDecoder = JSONDecoder()
        // Используем кастомную стратегию декодирования с нашим форматером
        jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = Self.iso8601Formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        // Настраиваем енкодер для работы с датами в формате ISO 8601
        self.jsonEncoder = JSONEncoder()
        // Используем кастомную стратегию кодирования, чтобы даты всегда отправлялись в одном формате
        jsonEncoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let dateString = Self.iso8601Formatter.string(from: date)
            try container.encode(dateString)
        }
    }
    
    // MARK: - Generic REST Methods
    
    /// **PULL**: Загружает массив объектов с сервера (GET-запрос).
    /// - Parameters:
    ///   - endpoint: Путь к API эндпоинту (например, `APIConstants.Endpoints.groups`).
    ///   - authToken: Токен аутентификации пользователя.
    ///   - lastSyncTimestamp: Дата последней синхронизации для получения только обновленных данных.
    /// - Returns: Массив декодированных объектов.
    func fetch<T: Decodable>(endpoint: String, authToken: String, lastSyncTimestamp: Date?) async throws -> [T] {
        var url = baseURL.appendingPathComponent(endpoint)
        
        // Если есть timestamp, добавляем его как query-параметр
        if let timestamp = lastSyncTimestamp {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "since", value: timestamp.ISO8601Format())]
            url = components.url!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Устанавливаем заголовок авторизации
        request.setValue("Token \(authToken)", forHTTPHeaderField: "Authorization")
        
        return try await performRequest(request)
    }
    
    /// **PUSH (Bulk)**: Отправляет массив объектов на сервер (POST-запрос).
    /// - Parameters:
    ///   - items: Массив объектов для отправки, соответствующих протоколу `Encodable`.
    ///   - endpoint: Путь к API эндпоинту.
    ///   - authToken: Токен аутентификации пользователя.
    /// - Returns: Массив декодированных объектов, возвращенных сервером.
    func post<T: Codable>(items: [T], endpoint: String, authToken: String) async throws -> [T] {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(authToken)", forHTTPHeaderField: "Authorization")
        
        // Кодируем массив объектов в тело запроса
        request.httpBody = try jsonEncoder.encode(items)
        
        // Для отладки
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("⬆️ PUSH to \(endpoint): \(bodyString)")
        }
        
        return try await performRequest(request)
    }
    
    // MARK: - Private Request Handler
    
    /// Приватный метод, который выполняет фактический сетевой запрос и обработку ответа.
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        print("🌍 Requesting URL: \(request.url?.absoluteString ?? "N/A")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.networkError(statusCode: -1, data: data)
        }
        
        // Логируем статус-код для отладки
        print("⬇️ Response from \(request.url?.path() ?? ""): Status \(httpResponse.statusCode)")
        
        // Успешный ответ
        if (200...299).contains(httpResponse.statusCode) {
            do {
                let decodedResponse = try jsonDecoder.decode(T.self, from: data)
                return decodedResponse
            } catch {
                print("❌ Decoding Error: \(error)")
                throw SyncError.decodingError(error)
            }
        } else { // Ошибка
            // Логируем тело ответа при ошибке
            if let errorBody = String(data: data, encoding: .utf8) {
                print("❌ Error Body: \(errorBody)")
            }
            throw SyncError.networkError(statusCode: httpResponse.statusCode, data: data)
        }
    }
}