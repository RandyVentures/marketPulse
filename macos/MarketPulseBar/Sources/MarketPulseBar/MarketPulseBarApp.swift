import AppKit
import Combine
import MarketPulseCore
import MarketPulseUI
import SwiftUI

@main
struct MarketPulseBarApp: App {
    @StateObject private var service: MarketPulseService
    @State private var showSettings = false

    private static let dataDir = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".marketpulse")
        .appendingPathComponent("data")
    private let notificationController: MarketPulseNotificationController
    private let snapshotCancellable: AnyCancellable

    init() {
        let logsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
        let config = MarketPulseConfiguration(
            allowLocal: true,
            dataDirectory: Self.dataDir,
            logFileURL: logsDir.appendingPathComponent("MarketPulseBar.log")
        )
        let service = MarketPulseService(configuration: config, settings: MarketPulseSettings())
        let notificationController = MarketPulseNotificationController()
        _service = StateObject(wrappedValue: service)
        self.notificationController = notificationController
        self.snapshotCancellable = service.$snapshot
            .compactMap { $0 }
            .sink { snapshot in
                notificationController.consider(snapshot: snapshot)
            }
        notificationController.requestAuthorization()
        service.start()
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showSettings.toggle()
                        }
                    } label: {
                        Image(systemName: showSettings ? "xmark.circle" : "gearshape")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                ScrollView {
                    if showSettings {
                        SettingsView(settings: service.settings)
                            .padding(10)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            if let snapshot = service.snapshot {
                                SectionContainer {
                                    MenuHeaderView(snapshot: snapshot, lastUpdated: service.lastUpdated, isStale: service.isStale)
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
                        try? FileManager.default.createDirectory(
                            at: Self.dataDir,
                            withIntermediateDirectories: true
                        )
                        NSWorkspace.shared.open(Self.dataDir)
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
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(menuDotColor)
                Text(menuTitle)
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuTitle: String {
        if let snapshot = service.snapshot {
            return "MP \(snapshot.label.rawValue) \(snapshot.score)"
        }
        return "MP --"
    }

    private var menuDotColor: Color {
        service.snapshot?.label.color ?? .gray
    }
}
