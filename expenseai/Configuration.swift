import Foundation

struct APIConstants {
    static let baseURL = "https://sharewithme.club:8379"

    struct Endpoints {
        static let login = "/auth/token/login/"
        static let register = "/exp-app/auth/users/"
        static let me = "/exp-app/auth/users/me/"
        // Сюда можно будет добавлять другие пути, например:
        // static let groups = "/exp-app/groups/"
        // static let participants = "/exp-app/participants/"
    }
}