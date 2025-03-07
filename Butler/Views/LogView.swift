import SwiftUI

struct LogView: View {
    @ObservedObject var logger = LoggerService.shared
    @State private var searchText = ""
    @State private var selectedType: LoggerService.LogType?
    @State private var autoScroll = true
    
    private var filteredLogs: [LoggerService.LogEntry] {
        logger.logs.filter { entry in
            let matchesSearch = searchText.isEmpty || 
                entry.message.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || entry.type == selectedType
            return matchesSearch && matchesType
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search logs...", text: $searchText)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Filter menu
                Picker("Filter", selection: $selectedType) {
                    Text("All").tag(nil as LoggerService.LogType?)
                    Text("Info").tag(LoggerService.LogType.info as LoggerService.LogType?)
                    Text("Warning").tag(LoggerService.LogType.warning as LoggerService.LogType?)
                    Text("Error").tag(LoggerService.LogType.error as LoggerService.LogType?)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                
                Spacer()
                
                // Actions
                Toggle(isOn: $autoScroll) {
                    Image(systemName: "arrow.down.to.line")
                }
                .toggleStyle(.button)
                .help("Auto-scroll to latest logs")
                
                Button(action: { logger.clearLogs() }) {
                    Image(systemName: "trash")
                }
                .help("Clear logs")
                
                Button(action: copyLogs) {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy logs")
            }
            .padding()
            
            Divider()
            
            // Log list
            ScrollViewReader { proxy in
                List(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
                .onChange(of: logger.logs) { _ in
                    if autoScroll, let lastLog = filteredLogs.last {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private func copyLogs() {
        let logText = logger.exportLogs()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
    }
}

struct LogEntryRow: View {
    let entry: LoggerService.LogEntry
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Timestamp and type
            HStack {
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(entry.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(entry.type.color.opacity(0.1))
                    .foregroundColor(entry.type.color)
                    .cornerRadius(4)
            }
            
            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    LogView()
}
