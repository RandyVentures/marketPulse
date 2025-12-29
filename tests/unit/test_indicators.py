import pandas as pd

from marketpulse.indicators import ema, macd, ratio_series, sma, weekly_series


def test_weekly_series():
    dates = pd.date_range("2024-01-01", periods=20, freq="D")
    df = pd.DataFrame({"date": dates, "close": range(20)})
    weekly = weekly_series(df)
    assert not weekly.empty
    assert weekly.index.freqstr.startswith("W")


def test_macd_shapes():
    series = pd.Series(range(1, 60))
    macd_line, signal_line = macd(series)
    assert len(macd_line) == len(series)
    assert len(signal_line) == len(series)


def test_ratio_series():
    a = pd.Series([2.0, 4.0, 6.0])
    b = pd.Series([1.0, 2.0, 3.0])
    ratio = ratio_series(a, b)
    assert ratio.tolist() == [2.0, 2.0, 2.0]


def test_ema_sma_monotonic():
    series = pd.Series(range(1, 10))
    ema_vals = ema(series, 3)
    sma_vals = sma(series, 3)
    assert ema_vals.iloc[-1] >= ema_vals.iloc[0]
    assert sma_vals.iloc[-1] >= sma_vals.iloc[0]
