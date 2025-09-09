import Foundation

/// `APIService` инкапсулирует всю работу с сетью.
/// Использует Swift Concurrency (async/await).
final class APIService {
    
    // Синглтон для удобного доступа
    static let shared = APIService()
    
    private let baseURL = URL(string: "http://127.0.0.1:8000/api/v1")! // TODO: Вынести в конфигурацию
    
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    private init() {
        self.session = URLSession(configuration: .default)
        
        self.jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        
        self.jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
    }
    
    /// Основной метод для выполнения запроса к эндпоинту /sync
    func performSync(payload: SyncRequestPayload) async throws -> SyncResponsePayload {
        let url = baseURL.appendingPathComponent("sync/") // TODO: Уточнить имя эндпоинта
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // TODO: Добавить заголовок авторизации (Bearer Token)
        // request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try jsonEncoder.encode(payload)
        
        print("Sending payload to server: \(String(data: request.httpBody!, encoding: .utf8) ?? "{}")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // TODO: Обработать ошибки сервера более детально
            throw SyncError.networkError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, data: data)
        }
        
        do {
            let decodedResponse = try jsonDecoder.decode(SyncResponsePayload.self, from: data)
            return decodedResponse
        } catch {
            print("Failed to decode sync response: \(error)")
            throw SyncError.decodingError(error)
        }
    }
}