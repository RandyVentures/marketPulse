# marketPulse

Personal market health terminal dashboard for macOS.

## Quick start

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .

marketpulse snapshot
marketpulse run
```

## Menu bar app (macOS)

Native SwiftUI menubar app lives in `marketPulse/macos/MarketPulseBar`.
See install steps in `marketPulse/macos/MarketPulseBar/README.md`.

## Data notes

- Place manual CSVs in `~/.marketpulse/data/`.
- Supported filenames:
  - `SPY.csv`, `RSP.csv` (OHLCV with a `date` column)
  - `breadth.csv` (columns: `date`, `advances`, `declines`, `new_highs`, `new_lows`)

If no local data is available, the CLI will attempt to fetch from free sources.
