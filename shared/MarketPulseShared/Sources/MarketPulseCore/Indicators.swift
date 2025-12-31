import Foundation

public enum IndicatorMath {
    public static func sma(_ series: [Double], window: Int) -> [Double] {
        guard window > 0 else { return series }
        var result: [Double] = []
        for idx in 0..<series.count {
            let start = max(0, idx - window + 1)
            let slice = series[start...idx]
            let avg = slice.reduce(0, +) / Double(slice.count)
            result.append(avg)
        }
        return result
    }

    public static func ema(_ series: [Double], span: Int) -> [Double] {
        guard !series.isEmpty else { return [] }
        let alpha = 2.0 / (Double(span) + 1.0)
        var result: [Double] = []
        var current = series[0]
        result.append(current)
        for value in series.dropFirst() {
            current = alpha * value + (1 - alpha) * current
            result.append(current)
        }
        return result
    }

    public static func macd(
        _ series: [Double],
        fast: Int = 12,
        slow: Int = 26,
        signal: Int = 9
    ) -> (line: [Double], signal: [Double]) {
        let fastEma = ema(series, span: fast)
        let slowEma = ema(series, span: slow)
        let macdLine = zip(fastEma, slowEma).map { $0 - $1 }
        let signalLine = ema(macdLine, span: signal)
        return (macdLine, signalLine)
    }

    public static func cumulative(_ series: [Double]) -> [Double] {
        var total = 0.0
        return series.map { value in
            total += value
            return total
        }
    }
}
