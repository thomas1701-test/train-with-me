import Foundation

enum Secrets {
    static var geminiKey: String {
        Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""
    }
}
