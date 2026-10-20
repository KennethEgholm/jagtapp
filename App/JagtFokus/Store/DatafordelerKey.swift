import Foundation

/// The Datafordeler API key from the gitignored `App/Config/Secrets.xcconfig`, through
/// Info.plist. Nil when it is missing, empty, still the unexpanded `$(…)`, or the
/// placeholder from `Secrets.example.xcconfig`.
enum DatafordelerKey {
    /// The placeholder in `Secrets.example.xcconfig`. A copy of the example is not a key.
    static let placeholder = "din-nøgle"

    static let value: String? = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "DatafordelerApiKey") as? String
        guard let key = raw?.trimmingCharacters(in: .whitespaces), !key.isEmpty, !key.hasPrefix("$("),
              key != placeholder else { return nil }
        return key
    }()
}
