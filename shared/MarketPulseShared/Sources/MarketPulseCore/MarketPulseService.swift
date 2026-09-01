import Combine
import Foundation

public struct MarketPulseConfiguration {
    public var allowLocal: Bool
    public var dataDirectory: URL?
    public var logFileURL: URL?
    public var snapshotFileURL: URL?

    public init(
        allowLocal: Bool = false,
        dataDirectory: URL? = nil,
        logFileURL: URL? = nil,
        snapshotFileURL: URL? = nil
    ) {
        self.allowLocal = allowLocal
        self.dataDirectory = dataDirectory
        self.logFileURL = logFileURL
        self.snapshotFileURL = snapshotFileURL
    }

    public static var `default`: MarketPulseConfiguration {
        MarketPulseConfiguration()
    }
}

@MainActor
public final class MarketPulseService: ObservableObject {
    @Published public var snapshot: MarketPulseSnapshot?
    @Published public var errorMessage: String?
    @Published public var lastUpdated: Date?
    @Published public var statusMessage: String?
    @Published public var logPath: String?
    @Published public var isRefreshing = false
    @Published public var isStale = false

    public let settings: MarketPulseSettings

    private let fetcher: MarketDataFetcher
    private let engine = MarketPulseEngine()
    private var timer: Timer?
    private let logURL: URL?
    private let snapshotURL: URL?
    private var cancellables = Set<AnyCancellable>()

    private struct PersistedState: Codable {
        let snapshot: MarketPulseSnapshot
        let lastUpdated: Date
    }

    public init(configuration: MarketPulseConfiguration = .default, settings: MarketPulseSettings) {
        self.fetcher = MarketDataFetcher(
            dataDirectory: configuration.dataDirectory,
            allowLocal: configuration.allowLocal
        )
        self.logURL = configuration.logFileURL
        self.snapshotURL = configuration.snapshotFileURL ?? Self.defaultSnapshotURL
        self.logPath = configuration.logFileURL?.path
        self.settings = settings
        loadPersistedState()
        log("Initialized")

        settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateStaleState()
                self?.restartTimer()
            }
            .store(in: &cancellables)
    }

    public func start() {
        Task { await refresh() }
        restartTimer()
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() async {
        if isRefreshing {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            log("Refresh start")
            async let spy = fetcher.loadPricesWithHealth(symbol: "SPY")
            async let rsp = fetcher.loadPricesWithHealth(symbol: "RSP")
            async let vix = fetcher.loadVixWithHealth()
            async let breadth = fetcher.loadBreadthWithHealth()
            let spyResult = try await spy
            let rspResult = try await rsp
            let vixResult = try await vix
            let breadthResult = await breadth
            let snapshot = engine.buildSnapshot(
                spy: spyResult.values,
                rsp: rspResult.values,
                vix: vixResult.values,
                breadth: breadthResult.values,
                thresholds: settings.thresholds,
                dataHealth: [
                    spyResult.health,
                    rspResult.health,
                    vixResult.health,
                    breadthResult.health
                ]
            )
            self.snapshot = snapshot
            self.errorMessage = nil
            self.statusMessage = "OK"
            let refreshedAt = Date()
            self.lastUpdated = refreshedAt
            self.isStale = false
            persist(snapshot: snapshot, lastUpdated: refreshedAt)
            log("Refresh ok")
        } catch {
            self.errorMessage = error.localizedDescription
            self.statusMessage = "Failed"
            self.updateStaleState()
            log("Refresh failed: \(error.localizedDescription)")
        }
    }

    private func updateStaleState(now: Date = Date()) {
        guard errorMessage != nil, let lastUpdated else {
            isStale = false
            return
        }
        isStale = now.timeIntervalSince(lastUpdated) > settings.refreshInterval
    }

    private static var defaultSnapshotURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MarketPulse", isDirectory: true)
            .appendingPathComponent("snapshot.json")
    }

    private func loadPersistedState() {
        guard let snapshotURL, FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        do {
            let data = try Data(contentsOf: snapshotURL)
            let state = try JSONDecoder().decode(PersistedState.self, from: data)
            snapshot = state.snapshot
            lastUpdated = state.lastUpdated
            statusMessage = "Cached"
        } catch {
            log("Cached snapshot load failed: \(error.localizedDescription)")
        }
    }

    private func persist(snapshot: MarketPulseSnapshot, lastUpdated: Date) {
        guard let snapshotURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let state = PersistedState(snapshot: snapshot, lastUpdated: lastUpdated)
            let data = try JSONEncoder().encode(state)
            try data.write(to: snapshotURL, options: .atomic)
        } catch {
            log("Snapshot persistence failed: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        guard let logURL else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        do {
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try FileManager.default.createDirectory(
                    at: logURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            // ignore logging errors
        }
    }
}
