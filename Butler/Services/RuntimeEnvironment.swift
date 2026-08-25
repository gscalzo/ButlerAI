import Foundation

enum RuntimeEnvironment {
    static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
    }
}

/// Version information for display in the UI, read from the bundle's Info.plist.
enum AppInfo {
    static let name = "ButlerAI"
    static let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    static let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    /// e.g. "Version 1.1.0 (2)"
    static var versionDescription: String { versionDescription(version: version, build: build) }

    static func versionDescription(version: String, build: String) -> String {
        "Version \(version) (\(build))"
    }
}
