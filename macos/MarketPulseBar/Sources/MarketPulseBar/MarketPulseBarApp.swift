import AppKit
import MarketPulseCore
import MarketPulseUI
import SwiftUI

@main
struct MarketPulseBarApp: App {
    @StateObject private var service: MarketPulseService

    init() {
        let dataDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".marketpulse")
            .appendingPathComponent("data")
        let logsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
        let config = MarketPulseConfiguration(
            refreshInterval: 300,
            allowLocal: true,
            dataDirectory: dataDir,
            logFileURL: logsDir.appendingPathComponent("MarketPulseBar.log")
        )
        let service = MarketPulseService(configuration: config)
        _service = StateObject(wrappedValue: service)
        service.start()
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let snapshot = service.snapshot {
                            SectionContainer {
                                MenuHeaderView(snapshot: snapshot, lastUpdated: service.lastUpdated)
                            }
                            SnapshotSignalsView(snapshot: snapshot)
                        } else {
                            SectionContainer {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("No data yet")
                                        .font(.headline)
                                    if let lastUpdated = service.lastUpdated {
                                        Text("Last update: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let status = service.statusMessage {
                                        Text("Status: \(status)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let errorMessage = service.errorMessage {
                                        Text(errorMessage)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(10)
                }
                Divider()
                HStack(spacing: 12) {
                    Button {
                        Task { await service.refresh() }
                    } label: {
                        if service.isRefreshing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Refreshing")
                            }
                        } else {
                            Text("Refresh")
                        }
                    }
                    .disabled(service.isRefreshing)
                    Button("Data Folder") {
                        let path = FileManager.default
                            .homeDirectoryForCurrentUser
                            .appendingPathComponent(".marketpulse")
                            .appendingPathComponent("data")
                        NSWorkspace.shared.open(path)
                    }
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding(10)
            }
            .frame(width: 320, height: 420)
        } label: {
            Text(menuTitle)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuTitle: String {
        if let snapshot = service.snapshot {
            return "MP \(snapshot.label.rawValue) \(snapshot.score)"
        }
        return "MP --"
    }
}
