import Foundation
import SwiftUI

func log(_ message: String, type: LoggerService.LogType = .info, file: String = #file, function: String = #function, line: Int = #line) {
    LoggerService.shared.log(message, type: type, file: file, function: function, line: line)
}

class LoggerService: ObservableObject {
    @Published var logs: [LogEntry] = []
    private let dateFormatter: DateFormatter
    static let shared = LoggerService()

    /// On-disk copy of the log (inside the app's sandbox container when sandboxed), for diagnosing
    /// problems when the app was launched from Finder and `print` output is not visible.
    static let logFileURL: URL = {
        let logsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        return logsDirectory.appendingPathComponent("ButlerAI.log")
    }()
    private static let maxLogFileSize: UInt64 = 2_000_000

    private let fileQueue = DispatchQueue(label: "uk.co.effectivecode.Butler.logfile", qos: .utility)
    private lazy var fileHandle: FileHandle? = Self.openLogFile()
    
    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let type: LogType
        
        static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum LogType: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var color: Color {
            switch self {
            case .info: return .primary
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    private init() {
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    func log(_ message: String, type: LogType = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let entry = LogEntry(
            timestamp: Date(),
            message: message,
            type: type
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.logs.append(entry)
        }
        
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let fileName = (file as NSString).lastPathComponent
        let line = "[\(timestamp)] [\(type.rawValue)] [\(fileName):\(line)] \(message)"
        print(line)

        guard !RuntimeEnvironment.isRunningTests else { return }
        fileQueue.async { [weak self] in
            self?.fileHandle?.write(Data((line + "\n").utf8))
        }
    }

    private static func openLogFile() -> FileHandle? {
        let url = logFileURL
        let fileManager = FileManager.default
        if let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size]) as? UInt64, size > maxLogFileSize {
            try? fileManager.removeItem(at: url)
        }
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else {
            print("[LoggerService] Could not open log file at \(url.path)")
            return nil
        }
        handle.seekToEndOfFile()
        return handle
    }
    
    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
        }
    }
    
    func exportLogs() -> String {
        return logs.map { entry in
            let timestamp = dateFormatter.string(from: entry.timestamp)
            return "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
