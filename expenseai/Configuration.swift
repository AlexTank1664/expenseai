import Foundation

struct APIConstants {
 //   static let baseURL = "https://sharewithme.club:8443"
    static let baseURL = "https://api.sharewithme.club"

    //static let baseURL = "http://127.0.0.1:8000"
    

    struct Endpoints {
        static let login = "/auth/token/login/"
        
        static let register = "/exp-app/auth/users/"
        static let me = "/exp-app/auth/users/me/"
        
        // MARK: - Password Reset & Verification
        static let sendPasswordResetEmail = "/exp-app/auth/send-password-reset-email/"
        static let sendVerificationEmail = "/exp-app/auth/send-verification-email/"
        
        // MARK: - Sync Endpoints
        // Remove the old sync endpoint
        // static let sync = "/exp-app/sync/"
        
        // Add the new RESTful endpoints
        static let currencies = "/exp-app/currencies/"
        static let participants = "/exp-app/participants/"
        static let groups = "/exp-app/groups/"
        static let expenses = "/exp-app/expenses/"
    }
}
