import Combine
import Foundation

public struct MarketPulseConfiguration {
    public var allowLocal: Bool
    public var dataDirectory: URL?
    public var logFileURL: URL?

    public init(
        allowLocal: Bool = false,
        dataDirectory: URL? = nil,
        logFileURL: URL? = nil
    ) {
        self.allowLocal = allowLocal
        self.dataDirectory = dataDirectory
        self.logFileURL = logFileURL
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
    private var cancellables = Set<AnyCancellable>()

    public init(configuration: MarketPulseConfiguration = .default, settings: MarketPulseSettings) {
        self.fetcher = MarketDataFetcher(
            dataDirectory: configuration.dataDirectory,
            allowLocal: configuration.allowLocal
        )
        self.logURL = configuration.logFileURL
        self.logPath = configuration.logFileURL?.path
        self.settings = settings
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
            async let spy = fetcher.loadPrices(symbol: "SPY")
            async let rsp = fetcher.loadPrices(symbol: "RSP")
            async let vix = fetcher.loadVix()
            async let breadth = fetcher.loadBreadth()
            let snapshot = engine.buildSnapshot(
                spy: try await spy,
                rsp: try await rsp,
                vix: try await vix,
                breadth: try await breadth,
                thresholds: settings.thresholds
            )
            self.snapshot = snapshot
            self.errorMessage = nil
            self.statusMessage = "OK"
            self.lastUpdated = Date()
            self.isStale = false
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
