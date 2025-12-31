# marketPulse

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/)

Personal market health dashboard with CLI, macOS menu bar app, and iOS app.

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

## Swift apps (macOS + iOS)

Shared SwiftUI core + views live in `shared/MarketPulseShared` and are consumed by:
- macOS menu bar app in `macos/MarketPulseBar`
- iOS app in `ios/MarketPulseApp`

### Install the menu bar app (macOS)

1) Download the latest `MarketPulseBar.app.zip` from GitHub Releases.
2) Unzip and move `MarketPulseBar.app` to `/Applications`.
3) Open it (first run: right-click → Open).

### Build the menu bar app from source (macOS)

```bash
cd macos/MarketPulseBar
swift build
swift run
```

### Run the iOS app (iOS)

Open `ios/MarketPulseApp/MarketPulseApp.xcodeproj` in Xcode and run on a simulator or device.
The iOS app fetches data from Stooq + FRED (network-only) and supports pull-to-refresh.

### Troubleshooting (macOS)

If macOS reports the app is "damaged", it is usually Gatekeeper quarantining an unsigned app.
After moving the app to `/Applications`, run:

```bash
xattr -dr com.apple.quarantine /Applications/MarketPulseBar.app
```

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
- Create a release by pushing a tag, for example:

```bash
git tag v0.1.0
git push origin v0.1.0
```
