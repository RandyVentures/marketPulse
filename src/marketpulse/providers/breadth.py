"""Breadth providers."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

import pandas as pd

from marketpulse.config import DEFAULT_CONFIG
from marketpulse.providers.base import BreadthDataProvider, ProviderChain, ProviderChainError
from marketpulse.utils import normalize_breadth


class LocalCsvBreadthProvider(BreadthDataProvider):
    def __init__(self, data_dir: Optional[Path] = None) -> None:
        self.data_dir = data_dir or DEFAULT_CONFIG.data_dir

    def fetch_daily(self) -> pd.DataFrame:
        path = self.data_dir / "breadth.csv"
        if not path.exists():
            raise FileNotFoundError(f"Missing local CSV: {path}")
        df = pd.read_csv(path)
        return normalize_breadth(df)


class BreadthProviderChain(ProviderChain, BreadthDataProvider):
    def __init__(self, providers: Optional[list[BreadthDataProvider]] = None) -> None:
        super().__init__(label="Breadth data")
        self.providers = providers or [LocalCsvBreadthProvider()]

    def fetch_daily(self) -> pd.DataFrame:
        for provider in self.providers:
            try:
                data = provider.fetch_daily()
                if not data.empty:
                    return data
            except Exception as exc:  # pragma: no cover
                self.record_error(exc)
        raise ProviderChainError(self.label, self.errors)
