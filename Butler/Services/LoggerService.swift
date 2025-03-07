import Foundation
import SwiftUI

class LoggerService: ObservableObject {
    @Published var logs: [LogEntry] = []
    private let dateFormatter: DateFormatter
    static let shared = LoggerService()
    
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
        print("[\(timestamp)] [\(type.rawValue)] [\(fileName):\(line)] \(message)")
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
