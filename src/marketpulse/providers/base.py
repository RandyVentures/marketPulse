"""Provider interfaces."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional

import pandas as pd


class MarketDataProvider(ABC):
    @abstractmethod
    def fetch_daily(self, symbol: str) -> pd.DataFrame:
        raise NotImplementedError


class VixDataProvider(ABC):
    @abstractmethod
    def fetch_daily(self) -> pd.DataFrame:
        raise NotImplementedError


class BreadthDataProvider(ABC):
    @abstractmethod
    def fetch_daily(self) -> pd.DataFrame:
        raise NotImplementedError


class ProviderError(RuntimeError):
    pass


class ProviderChainError(ProviderError):
    def __init__(self, label: str, errors: list[str]) -> None:
        message = f"{label} failed: " + "; ".join(errors)
        super().__init__(message)
        self.label = label
        self.errors = errors


class ProviderChain:
    def __init__(self, label: str) -> None:
        self.label = label
        self.errors: list[str] = []

    def record_error(self, exc: Exception) -> None:
        self.errors.append(str(exc))

    def raise_if_empty(self, result: Optional[pd.DataFrame]) -> pd.DataFrame:
        if result is None or result.empty:
            raise ProviderChainError(self.label, self.errors or ["no data returned"])
        return result
