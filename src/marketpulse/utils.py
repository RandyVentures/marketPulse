"""Utility helpers."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Iterable

import pandas as pd


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def parse_date(value: str) -> datetime:
    return pd.to_datetime(value).to_pydatetime()


def normalize_ohlcv(df: pd.DataFrame) -> pd.DataFrame:
    columns = {"date": "date", "open": "open", "high": "high", "low": "low", "close": "close", "volume": "volume"}
    lower = {col.lower(): col for col in df.columns}
    mapped = {}
    for key, target in columns.items():
        if key in lower:
            mapped[lower[key]] = target
    normalized = df.rename(columns=mapped)
    needed = ["date", "open", "high", "low", "close"]
    missing = [col for col in needed if col not in normalized.columns]
    if missing:
        raise ValueError(f"Missing columns: {missing}")
    normalized["date"] = pd.to_datetime(normalized["date"])
    normalized = normalized.sort_values("date").reset_index(drop=True)
    return normalized


def normalize_breadth(df: pd.DataFrame) -> pd.DataFrame:
    required = ["date", "advances", "declines", "new_highs", "new_lows"]
    lower = {col.lower(): col for col in df.columns}
    mapped = {}
    for key in required:
        if key in lower:
            mapped[lower[key]] = key
    normalized = df.rename(columns=mapped)
    missing = [col for col in required if col not in normalized.columns]
    if missing:
        raise ValueError(f"Missing columns: {missing}")
    normalized["date"] = pd.to_datetime(normalized["date"])
    normalized = normalized.sort_values("date").reset_index(drop=True)
    return normalized


def normalize_vix(df: pd.DataFrame) -> pd.DataFrame:
    lower = {col.lower(): col for col in df.columns}
    if "date" not in lower:
        raise ValueError("Missing date column")
    value_col = None
    for key in ("vix", "close", "value"):
        if key in lower:
            value_col = lower[key]
            break
    if value_col is None:
        raise ValueError("Missing VIX value column")
    normalized = df.rename(columns={lower["date"]: "date", value_col: "vix"})
    normalized["date"] = pd.to_datetime(normalized["date"])
    normalized = normalized.sort_values("date").reset_index(drop=True)
    return normalized


def latest_value(series: Iterable[float]) -> float:
    return list(series)[-1]
