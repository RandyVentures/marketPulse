"""Compute market pulse signals."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional

import pandas as pd

from marketpulse.config import DEFAULT_CONFIG, MarketPulseConfig
from marketpulse.indicators import cumulative, ema, macd, ratio_series, sma, slope, weekly_series
from marketpulse.models import MarketPulseSnapshot, Signal, Vote
from marketpulse.providers.breadth import BreadthProviderChain
from marketpulse.providers.market import MarketDataProviderChain
from marketpulse.providers.vix import VixProviderChain


@dataclass
class DataBundle:
    spy: pd.DataFrame
    rsp: pd.DataFrame
    vix: pd.DataFrame
    breadth: Optional[pd.DataFrame]


def load_data(
    market_provider: Optional[MarketDataProviderChain] = None,
    vix_provider: Optional[VixProviderChain] = None,
    breadth_provider: Optional[BreadthProviderChain] = None,
) -> DataBundle:
    market_provider = market_provider or MarketDataProviderChain()
    vix_provider = vix_provider or VixProviderChain()
    breadth_provider = breadth_provider or BreadthProviderChain()

    spy = market_provider.fetch_daily("SPY")
    rsp = market_provider.fetch_daily("RSP")
    vix = vix_provider.fetch_daily()

    breadth = None
    try:
        breadth = breadth_provider.fetch_daily()
    except Exception:
        breadth = None

    return DataBundle(spy=spy, rsp=rsp, vix=vix, breadth=breadth)


def _vote_from_bool(name: str, condition: bool, value: Optional[float], detail: str) -> Signal:
    return Signal(name=name, vote=Vote.BULL if condition else Vote.BEAR, value=value, detail=detail)


def _vote_na(name: str, detail: str) -> Signal:
    return Signal(name=name, vote=Vote.NA, value=None, detail=detail)


def build_signals(bundle: DataBundle, config: MarketPulseConfig = DEFAULT_CONFIG) -> List[Signal]:
    signals: List[Signal] = []

    spy_weekly = weekly_series(bundle.spy)
    macd_line, signal_line = macd(spy_weekly)
    macd_vote = macd_line.iloc[-1] > signal_line.iloc[-1]
    signals.append(
        _vote_from_bool(
            "Weekly MACD",
            macd_vote,
            macd_line.iloc[-1],
            f"MACD {macd_line.iloc[-1]:.2f} vs signal {signal_line.iloc[-1]:.2f}",
        )
    )

    ma8 = sma(spy_weekly, 8)
    ma21 = sma(spy_weekly, 21)
    signals.append(
        _vote_from_bool(
            "8/21 Weekly MA",
            ma8.iloc[-1] > ma21.iloc[-1],
            ma8.iloc[-1] - ma21.iloc[-1],
            f"8W {ma8.iloc[-1]:.2f} vs 21W {ma21.iloc[-1]:.2f}",
        )
    )

    ema8 = ema(spy_weekly, 8)
    ema_slope = slope(ema8, 1)
    signals.append(
        _vote_from_bool(
            "8W EMA Slope",
            ema_slope.iloc[-1] > 0,
            ema_slope.iloc[-1],
            f"Slope {ema_slope.iloc[-1]:.2f}",
        )
    )

    if bundle.breadth is not None:
        ad_daily = bundle.breadth["advances"] - bundle.breadth["declines"]
        cum_ad = cumulative(ad_daily)
        ad_ema89 = ema(cum_ad, 89)
        signals.append(
            _vote_from_bool(
                "Cum A/D vs 89-EMA",
                cum_ad.iloc[-1] > ad_ema89.iloc[-1],
                cum_ad.iloc[-1] - ad_ema89.iloc[-1],
                f"Cum {cum_ad.iloc[-1]:.0f} vs EMA {ad_ema89.iloc[-1]:.0f}",
            )
        )

        nhnl_daily = bundle.breadth["new_highs"] - bundle.breadth["new_lows"]
        cum_nhnl = cumulative(nhnl_daily)
        nhnl_ma10 = sma(cum_nhnl, 10)
        signals.append(
            _vote_from_bool(
                "NHNL Cum vs 10-MA",
                cum_nhnl.iloc[-1] > nhnl_ma10.iloc[-1],
                cum_nhnl.iloc[-1] - nhnl_ma10.iloc[-1],
                f"Cum {cum_nhnl.iloc[-1]:.0f} vs MA {nhnl_ma10.iloc[-1]:.0f}",
            )
        )

        osc = ema(ad_daily, 19) - ema(ad_daily, 39)
        nysi = cumulative(osc)
        nysi_slope = nysi.iloc[-1] - nysi.iloc[-6] if len(nysi) > 6 else nysi.diff().iloc[-1]
        signals.append(
            _vote_from_bool(
                "NYSI Slope",
                nysi_slope > 0,
                nysi_slope,
                f"Slope {nysi_slope:.2f}",
            )
        )
    else:
        signals.append(_vote_na("Cum A/D vs 89-EMA", "Breadth unavailable"))
        signals.append(_vote_na("NHNL Cum vs 10-MA", "Breadth unavailable"))
        signals.append(_vote_na("NYSI Slope", "Breadth unavailable"))

    vix_latest = bundle.vix["vix"].iloc[-1]
    if vix_latest < config.vix_bull:
        vix_vote = Vote.BULL
    elif vix_latest <= config.vix_neutral:
        vix_vote = Vote.NEUTRAL
    else:
        vix_vote = Vote.BEAR
    signals.append(
        Signal(
            name="VIX Regime",
            vote=vix_vote,
            value=vix_latest,
            detail=f"VIX {vix_latest:.2f}",
        )
    )

    rsp_close = bundle.rsp.set_index("date")["close"]
    spy_close = bundle.spy.set_index("date")["close"]
    ratio = ratio_series(rsp_close, spy_close)
    ratio_sma = sma(ratio, 50)
    ratio_slope = slope(ratio, 1)
    signals.append(
        _vote_from_bool(
            "RSP/SPY Breadth",
            ratio.iloc[-1] > ratio_sma.iloc[-1] and ratio_slope.iloc[-1] > 0,
            ratio.iloc[-1],
            f"Ratio {ratio.iloc[-1]:.4f} vs SMA {ratio_sma.iloc[-1]:.4f}",
        )
    )

    return signals


def score_signals(signals: List[Signal], config: MarketPulseConfig = DEFAULT_CONFIG) -> tuple[int, Vote]:
    score_map = {Vote.BULL: 1, Vote.BEAR: -1, Vote.NEUTRAL: 0, Vote.NA: 0}
    raw = sum(score_map[signal.vote] for signal in signals)
    max_score = max(len(signals), 1)
    normalized = int(round((raw + max_score) / (2 * max_score) * 100))
    if normalized >= config.score_bull:
        label = Vote.BULL
    elif normalized >= config.score_neutral:
        label = Vote.NEUTRAL
    else:
        label = Vote.BEAR
    return normalized, label


def detect_conflicts(signals: List[Signal]) -> List[str]:
    conflicts: List[str] = []
    trend_votes = [s.vote for s in signals if s.name in {"Weekly MACD", "8/21 Weekly MA", "8W EMA Slope"}]
    breadth_votes = [s.vote for s in signals if s.name in {"Cum A/D vs 89-EMA", "NHNL Cum vs 10-MA", "NYSI Slope"}]
    if trend_votes and breadth_votes:
        if all(v == Vote.BULL for v in trend_votes) and any(v == Vote.BEAR for v in breadth_votes):
            conflicts.append("Trend bullish but breadth weakening")
        if all(v == Vote.BEAR for v in trend_votes) and any(v == Vote.BULL for v in breadth_votes):
            conflicts.append("Trend bearish but breadth improving")
    return conflicts


def build_snapshot(config: MarketPulseConfig = DEFAULT_CONFIG) -> MarketPulseSnapshot:
    bundle = load_data()
    signals = build_signals(bundle, config)
    score, label = score_signals(signals, config)
    conflicts = detect_conflicts(signals)
    as_of = max(bundle.spy["date"].iloc[-1], bundle.vix["date"].iloc[-1]).strftime("%Y-%m-%d")
    extras = {
        "vix": f"{bundle.vix['vix'].iloc[-1]:.2f}",
        "rsp_spy": f"{(bundle.rsp['close'].iloc[-1] / bundle.spy['close'].iloc[-1]):.4f}",
    }
    return MarketPulseSnapshot(as_of=as_of, score=score, label=label, signals=signals, conflicts=conflicts, extras=extras)
