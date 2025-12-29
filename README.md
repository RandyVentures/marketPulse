# marketPulse

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/)

Personal market health terminal dashboard for macOS.

## Quick start

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .

marketpulse snapshot
marketpulse run
```

## Basic usage

```bash
marketpulse --help
marketpulse snapshot
marketpulse run
```

## Menu bar app (macOS)

Native SwiftUI menubar app lives in `macos/MarketPulseBar`.
See install steps in `macos/MarketPulseBar/README.md`.

### Install the menu bar app

1) Download the latest `MarketPulseBar.app.zip` from GitHub Releases.
2) Unzip and move `MarketPulseBar.app` to `/Applications`.
3) Open it (first run: right-click → Open).

## Data notes

- Place manual CSVs in `~/.marketpulse/data/`.
- Supported filenames:
  - `SPY.csv`, `RSP.csv` (OHLCV with a `date` column)
  - `breadth.csv` (columns: `date`, `advances`, `declines`, `new_highs`, `new_lows`)

If no local data is available, the CLI will attempt to fetch from free sources.

## Contributing

Issues and PRs are welcome. For larger changes, please open an issue to discuss scope first.

## Releases

- Python package versions live in `pyproject.toml`.
- Swift app builds are published as GitHub Releases.
