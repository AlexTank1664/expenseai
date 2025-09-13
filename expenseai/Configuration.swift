import Foundation

struct APIConstants {
    //static let baseURL = "https://sharewithme.club:8379"
    static let baseURL = "http://127.0.0.1:8000/exp-app/"
    

    struct Endpoints {
        static let login = "/auth/token/login/"
        static let register = "/exp-app/auth/users/"
        static let me = "/exp-app/auth/users/me/"
        // Добавляем новый эндпоинт для синхронизации
        static let sync = "/exp-app/sync/"
        // Сюда можно будет добавлять другие пути, например:
        // static let groups = "/exp-app/groups/"
        // static let participants = "/exp-app/participants/"
    }
}