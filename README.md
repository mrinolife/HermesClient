# HermesClient

Native iOS client for your self-hosted Hermes Agent WebUI.

Built because Hermex (by Uzair Ansar) is closed-source and you wanted your own version with custom features.

## Architecture

```
┌─────────────────────────────┐
│  HermesClient (iOS native)  │
│  ┌───────────────────────┐  │
│  │  WKWebView            │  │
│  │  loading your WebUI   │  │
│  │  (aibo.tail065eca.    │  │
│  │   ts.net:8787)        │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │  Native toolbar       │  │
│  │  Settings / Sessions  │  │
│  │  Share / Pipeline     │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

## Features

- **WKWebView** — loads your Hermes WebUI, same as Hermex
- **Native nav** — toolbar, swipe gestures, native share sheet
- **Settings** — server URL, profile, model, dark mode toggle
- **Session cache** — recent sessions stored offline for quick access
- **Share extension** — send URLs/text from other apps into Hermes
- **JS bridge** — custom JS injected into WebView for skins, pets, pipeline status
- **Pipeline button** — quick check your bug bounty pipeline status (bounty-specific)

## Getting the .ipa

### Option 1: GitHub Actions (recommended)
1. Push this repo to GitHub
2. Go to Actions → Build iOS App → Run workflow
3. Download the unsigned .ipa artifact
4. Sideload with AltStore (free, 7-day refresh) or SideStore (auto-refresh)

### Option 2: Build locally on macOS
```bash
cd HermesClient
gem install xcodegen
xcodegen generate
xcodebuild -project HermesClient.xcodeproj -scheme HermesClient -sdk iphoneos CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build
```

### Option 3: $99 Apple Developer Program
Once signed, the GitHub Actions workflow can auto-sign and you get:
- No 7-day expiry
- TestFlight for beta distribution
- Push notifications (future feature)

## Custom JS Bridge

The app injects `jsbridge.js` into every page load. This gives native ↔ web communication:

| Feature | How it works |
|---------|-------------|
| Skin sync | `postMessage({type: 'hermes:set-skin', skin: 'nezuko'})` |
| Pet overlay | Injects pet canvas into WebView |
| Pipeline status | `window.__hermesPipeline.status()` |
| Agent activity | WebKit message handler → native indicator |

## Customization Points

Add your own features in these files:

- **`ContentView.swift`** — toolbar buttons, bottom bar, navigation
- **`SettingsView.swift`** — settings UI (pipeline status, server config)
- **`jsbridge.js`** — JavaScript features injected into the web page
- **`Extensions/AppState.swift`** — app state, cache, persistence
- **`WebView.swift`** — WKWebView config, navigation delegate, error handling

## Roadmap Ideas

- [ ] Pet renderer (native canvas overlay, not JS)
- [ ] Push notifications for cron completions
- [ ] Apple Watch companion (daily recap)
- [ ] Pipeline quick-check toolbar
- [ ] FaceID/TouchID lock
- [ ] Native LaTeX rendering override
- [ ] Gesture shortcuts (swipe to switch sessions)
