import Foundation
import Combine
import KeychainAccess

// MARK: - Структуры для парсинга ошибок API
struct APIErrorResponse: Codable {
    let nonFieldErrors: [String]?
    let email: [String]?
    let password: [String]?
    
    // Превращает все ошибки в одну строку
    var combinedErrorMessage: String {
        let errors = [nonFieldErrors, email, password].compactMap { $0 }.flatMap { $0 }
        return errors.joined(separator: "\n")
    }
}


class AuthService: ObservableObject {
    @Published var authToken: String?
    @Published var currentUser: User? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var registrationSuccessMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let keychain = Keychain(service: "a2.expenseai")

    init() {
        self.authToken = try? keychain.get("authToken")
        if isAuthenticated {
            fetchCurrentUser()
        }
    }

    var isAuthenticated: Bool {
        authToken != nil
    }
    
    var isUserLoaded: Bool {
        currentUser != nil
    }

    func login(email: String, password: String) {
        guard let url = buildURL(for: APIConstants.Endpoints.login) else { return }

        let loginRequest = LoginRequest(email: email, password: password)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(loginRequest)
        } catch {
            errorMessage = "Could not encode login data"
            return
        }
        
        isLoading = true

        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { (data, response) -> Data in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    // Пытаемся декодировать ошибку из тела ответа
                    let errorMessage = "Authorization error:" + (self.decodeError(from: data) ?? "Wrong email or password")
                    throw AppError(message: errorMessage)
                }
                return data
            }
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("Login error: \(error)")
                    // Отображаем ошибку, которую мы "пробросили" из tryMap
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            } receiveValue: { [weak self] response in
                self?.saveToken(response.auth_token)
                self?.fetchCurrentUser()
            }
            .store(in: &cancellables)
    }
    
    func fetchCurrentUser() {
        guard let token = authToken else {
            print("Attempted to fetch user but token is nil")
            return
        }

        guard let url = buildURL(for: APIConstants.Endpoints.me) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

        isLoading = true
        
        URLSession.shared.dataTaskPublisher(for: request)
            .print("[DEBUG] FetchCurrentUser:")
            .map(\.data)
            .decode(type: User.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Fetch user error: \(error)")
                    self?.errorMessage = "Could not load user profile. Please try login again"
                    self?.logout()
                }
            } receiveValue: { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
    }

    func register(firstName: String, lastName: String, email: String, password: String, password2: String) {
        if password != password2 {
            errorMessage = "Passwords do not match."
            return
        }
        
        guard let url = buildURL(for: APIConstants.Endpoints.register) else { return }

        let registrationRequest = RegistrationRequest(
            first_name: firstName,
            last_name: lastName,
            email: email,
            password: password,
            password2: password2
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(registrationRequest)
        } catch {
            errorMessage = "Could not encode register data"
            return
        }

        isLoading = true

        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { (data, response) -> Data in
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = self.decodeError(from: data) ?? "An error ocurred during registration process"
                    throw AppError(message: errorMessage)
                }
                return data
            }
            .decode(type: User.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("Registration error: \(error)")
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.registrationSuccessMessage = "You has been succesfully registered, \(response.first_name)! Now you can log in"
            }
            .store(in: &cancellables)
    }

    func logout() {
        self.authToken = nil
        self.currentUser = nil
        do {
            try self.keychain.remove("authToken")
        } catch {
            print("Could not remove token from keychain: \(error)")
        }
    }
    
    private func saveToken(_ token: String) {
        self.authToken = token
        do {
            try self.keychain.set(token, key: "authToken")
        } catch {
            print("Could not save token to keychain: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildURL(for endpoint: String) -> URL? {
        guard var urlComponents = URLComponents(string: APIConstants.baseURL) else {
            errorMessage = "Wrong root API URL"
            return nil
        }
        urlComponents.path = endpoint
        
        guard let url = urlComponents.url else {
            errorMessage = "Could not construct endpoint URL: \(endpoint)"
            return nil
        }
        return url
    }
    
    private func decodeError(from data: Data) -> String? {
        do {
            let apiError = try JSONDecoder().decode(APIErrorResponse.self, from: data)
            if !apiError.combinedErrorMessage.isEmpty {
                return apiError.combinedErrorMessage
            }
        } catch {
            // Если не удалось распарсить нашу структуру, может быть, это что-то другое
            if let stringError = String(data: data, encoding: .utf8) {
                return stringError
            }
        }
        return nil
    }
}
