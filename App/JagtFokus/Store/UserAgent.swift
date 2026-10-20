import Foundation

enum UserAgent {
    /// MET and OpenFreeMap ask for a User-Agent that says who is asking.
    static var app: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "JagtFokus/\(version) +https://github.com/KennethEgholm/jagtapp"
    }
}
