import Foundation

/// The Datafordeler API key from the gitignored `App/Config/Secrets.xcconfig`, through
/// Info.plist. Nil when it is missing, empty or still the unexpanded `$(…)`.
enum DatafordelerKey {
    static let value: String? = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "DatafordelerApiKey") as? String
        guard let key = raw?.trimmingCharacters(in: .whitespaces), !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }()
}
