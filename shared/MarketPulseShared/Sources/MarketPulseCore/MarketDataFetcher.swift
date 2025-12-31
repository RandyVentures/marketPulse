import Foundation

public final class MarketDataFetcher {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private let allowLocal: Bool
    private let dataDirectory: URL?

    public init(dataDirectory: URL? = nil, allowLocal: Bool = false) {
        self.dataDirectory = dataDirectory
        self.allowLocal = allowLocal
    }

    public func loadPrices(symbol: String) async throws -> [PriceBar] {
        if let local = try loadLocalPrices(symbol: symbol) {
            return local
        }
        return try await fetchStooq(symbol: symbol)
    }

    public func loadVix() async throws -> [VixPoint] {
        if let local = try loadLocalVix() {
            return local
        }
        return try await fetchFredVix()
    }

    public func loadBreadth() async throws -> [BreadthPoint]? {
        return try loadLocalBreadth()
    }

    private func localURL(filename: String) -> URL? {
        guard allowLocal, let dataDirectory else { return nil }
        return dataDirectory.appendingPathComponent(filename)
    }

    private func loadLocalPrices(symbol: String) throws -> [PriceBar]? {
        guard let path = localURL(filename: "\(symbol.uppercased()).csv") else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseStooqCSV(content)
    }

    private func loadLocalVix() throws -> [VixPoint]? {
        guard let path = localURL(filename: "VIX.csv") else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseVixCSV(content)
    }

    private func loadLocalBreadth() throws -> [BreadthPoint]? {
        guard let path = localURL(filename: "breadth.csv") else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return parseBreadthCSV(content)
    }

    private func fetchStooq(symbol: String) async throws -> [PriceBar] {
        let ticker = symbol.lowercased() + ".us"
        let url = URL(string: "https://stooq.com/q/d/l/?s=\(ticker)&i=d")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        return parseStooqCSV(content)
    }

    private func fetchFredVix() async throws -> [VixPoint] {
        let url = URL(string: "https://fred.stlouisfed.org/graph/fredgraph.csv?id=VIXCLS")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        return parseVixCSV(content)
    }

    private func parseStooqCSV(_ content: String) -> [PriceBar] {
        let lines = content.split(whereSeparator: \ .isNewline)
        guard lines.count > 1 else { return [] }
        var bars: [PriceBar] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",")
            guard parts.count >= 5 else { continue }
            let dateStr = String(parts[0])
            let closeStr = String(parts[4])
            guard let date = dateFormatter.date(from: dateStr), let close = Double(closeStr) else { continue }
            bars.append(PriceBar(date: date, close: close))
        }
        return bars.sorted { $0.date < $1.date }
    }

    private func parseVixCSV(_ content: String) -> [VixPoint] {
        let lines = content.split(whereSeparator: \ .isNewline)
        guard lines.count > 1 else { return [] }
        var points: [VixPoint] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",")
            guard parts.count >= 2 else { continue }
            let dateStr = String(parts[0])
            let valueStr = String(parts[1])
            if valueStr == "." { continue }
            guard let date = dateFormatter.date(from: dateStr), let value = Double(valueStr) else { continue }
            points.append(VixPoint(date: date, value: value))
        }
        return points.sorted { $0.date < $1.date }
    }

    private func parseBreadthCSV(_ content: String) -> [BreadthPoint] {
        let lines = content.split(whereSeparator: \ .isNewline)
        guard lines.count > 1 else { return [] }
        let header = lines.first?.split(separator: ",").map { $0.lowercased() } ?? []
        let dateIdx = header.firstIndex(of: "date")
        let advIdx = header.firstIndex(of: "advances")
        let decIdx = header.firstIndex(of: "declines")
        let nhIdx = header.firstIndex(of: "new_highs")
        let nlIdx = header.firstIndex(of: "new_lows")
        guard let d = dateIdx, let a = advIdx, let c = decIdx, let h = nhIdx, let l = nlIdx else {
            return []
        }
        var points: [BreadthPoint] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",")
            guard parts.count > max(d, a, c, h, l) else { continue }
            let dateStr = String(parts[d])
            guard let date = dateFormatter.date(from: dateStr) else { continue }
            guard
                let adv = Double(parts[a]),
                let dec = Double(parts[c]),
                let nh = Double(parts[h]),
                let nl = Double(parts[l])
            else { continue }
            points.append(BreadthPoint(date: date, advances: adv, declines: dec, newHighs: nh, newLows: nl))
        }
        return points.sorted { $0.date < $1.date }
    }
}
