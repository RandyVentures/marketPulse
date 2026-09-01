import MarketPulseCore
import MarketPulseUI
import SwiftUI

struct ContentView: View {
    @StateObject private var service: MarketPulseService
    @State private var showSettings = false

    init() {
        let config = MarketPulseConfiguration(allowLocal: false)
        _service = StateObject(wrappedValue: MarketPulseService(configuration: config, settings: MarketPulseSettings()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(16)
            }
            .navigationTitle("Market Pulse")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await service.refresh() }
                    } label: {
                        if service.isRefreshing {
                            ProgressView()
                        } else {
                            Text("Refresh")
                        }
                    }
                    .disabled(service.isRefreshing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .refreshable {
                await service.refresh()
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(settings: service.settings, onDone: { showSettings = false })
                        .padding(16)
                }
                .presentationDetents([.medium, .large])
            }
        }
        .task {
            service.start()
        }
    }
}
