"""Indicator computations."""

from __future__ import annotations

import pandas as pd


def ema(series: pd.Series, span: int) -> pd.Series:
    return series.ewm(span=span, adjust=False).mean()


def sma(series: pd.Series, window: int) -> pd.Series:
    return series.rolling(window=window, min_periods=1).mean()


def weekly_series(df: pd.DataFrame, value_col: str = "close") -> pd.Series:
    weekly = df.set_index("date")[value_col].resample("W-FRI").last()
    return weekly.dropna()


def macd(series: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9) -> tuple[pd.Series, pd.Series]:
    ema_fast = ema(series, fast)
    ema_slow = ema(series, slow)
    macd_line = ema_fast - ema_slow
    signal_line = ema(macd_line, signal)
    return macd_line, signal_line


def ratio_series(numerator: pd.Series, denominator: pd.Series) -> pd.Series:
    aligned = pd.concat([numerator, denominator], axis=1).dropna()
    return aligned.iloc[:, 0] / aligned.iloc[:, 1]


def cumulative(series: pd.Series) -> pd.Series:
    return series.cumsum()


def slope(series: pd.Series, periods: int = 1) -> pd.Series:
    return series.diff(periods)
