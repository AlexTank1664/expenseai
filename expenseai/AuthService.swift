import Foundation
import Combine
import KeychainAccess

class AuthService: ObservableObject {
    @Published var authToken: String?
    @Published var currentUser: User? = nil
    @Published var isLoading = false
    @Published var appError: AppError? = nil
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
        guard var urlComponents = URLComponents(string: APIConstants.baseURL) else {
            appError = AppError(message: "Неверный базовый URL API")
            return
        }
        urlComponents.path = APIConstants.Endpoints.login
        
        guard let url = urlComponents.url else {
            appError = AppError(message: "Не удалось создать URL для входа")
            return
        }

        let loginRequest = LoginRequest(email: email, password: password)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(loginRequest)
        } catch {
            appError = AppError(message: "Не удалось закодировать данные для входа.")
            return
        }
        
        isLoading = true

        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("Login error: \(error)")
                    self?.appError = AppError(message: "Неверный email или пароль.")
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
            print("Attempted to fetch user but token is nil.")
            return
        }

        guard var urlComponents = URLComponents(string: APIConstants.baseURL) else {
            appError = AppError(message: "Неверный базовый URL API")
            return
        }
        urlComponents.path = APIConstants.Endpoints.me
        
        guard let url = urlComponents.url else {
            appError = AppError(message: "Не удалось создать URL для получения пользователя")
            return
        }

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
                    self?.appError = AppError(message: "Не удалось загрузить профиль пользователя. Пожалуйста, войдите снова.")
                    self?.logout()
                }
            } receiveValue: { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
    }

    func register(firstName: String, lastName: String, email: String, password: String, password2: String) {
        if password != password2 {
            appError = AppError(message: "Пароли не совпадают.")
            return
        }
        
        guard var urlComponents = URLComponents(string: APIConstants.baseURL) else {
            appError = AppError(message: "Неверный базовый URL API")
            return
        }
        urlComponents.path = APIConstants.Endpoints.register
        
        guard let url = urlComponents.url else {
            appError = AppError(message: "Не удалось создать URL для регистрации")
            return
        }

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
            appError = AppError(message: "Не удалось закодировать данные для регистрации.")
            return
        }

        isLoading = true

        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: User.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Registration error: \(error)")
                    self?.appError = AppError(message: "Ошибка регистрации. Возможно, такой email уже используется.")
                }
            } receiveValue: { [weak self] response in
                self?.registrationSuccessMessage = "Вы успешно зарегистрированы, \(response.first_name)! Теперь вы можете войти."
            }
            .store(in: &cancellables)
    }

    func logout() {
        // Since this is called from UI (main thread), no need for async dispatch
        self.authToken = nil
        self.currentUser = nil
        do {
            try self.keychain.remove("authToken")
        } catch {
            print("Could not remove token from keychain: \(error)")
        }
    }
    
    private func saveToken(_ token: String) {
        // We are on the main thread, so we can set the token synchronously
        self.authToken = token
        do {
            try self.keychain.set(token, key: "authToken")
        } catch {
            print("Could not save token to keychain: \(error)")
        }
    }
}