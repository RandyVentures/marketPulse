# MarketPulseBar

Native macOS menu bar app for marketPulse.

## Requirements

- macOS 13 or newer (MenuBarExtra)
- Xcode Command Line Tools (for `swift build`/`swift run`)

## Run locally

```bash
cd macos/MarketPulseBar
swift run
```

The menu bar item fetches data directly from free sources (Stooq + FRED) or uses `~/.marketpulse/data` CSVs if present.
For breadth signals, add `~/.marketpulse/data/breadth.csv` with columns: `date,advances,declines,new_highs,new_lows`.

## Install from GitHub Releases (recommended)

1) Download the latest `MarketPulseBar.app.zip` from GitHub Releases.
2) Unzip and move `MarketPulseBar.app` to `/Applications`.
3) Open it (first run: right-click → Open).

Note: If you want to avoid the first-run warning, publish a signed + notarized build.

## Security / permissions

- No entitlements, no sandbox required
- Fetches public CSVs over HTTPS (Stooq and FRED)
- Only opens the `~/.marketpulse/data` folder when requested
