import Foundation

/// The language the app itself runs in. Taken from the app's own localizations, not from
/// the region, so dates, numbers and the system's controls stay in step with the text.
enum AppLanguage {
    /// "da" or "en". Falls back to the source language when neither matches.
    static var code: String {
        Bundle.main.preferredLocalizations.first ?? "da"
    }

    static var locale: Locale {
        Locale(identifier: code)
    }
}
