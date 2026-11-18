# Welcome artwork

- `TimoLogo.pdf` is the tintable vector mushroom exported from `AppIcons/Timo.svg` by `python3 scripts/build-welcome-logo.py`.
- `WelcomeIcon.png` is the single mushroom app icon, resized from `AppIcons/Previews/Timo.png`.
- `Search.png` and `Spaces.png` are real Timo screenshots captured on 2026-10-06
  in a disposable `TIMO_DATA_DIR` profile. They contain sample browsing data,
  with no personal browsing data. SwiftUI frames the relevant controls at runtime.
- The search capture uses Wikipedia’s Architecture article as a sample history
  and archived-tab title. The capture contains Timo’s own controls and background.

- `Search-*.png` are local PNG conversions of official engine favicons (retrieved November 10, 2026):
  `https://www.google.com/favicon.ico`, `https://duckduckgo.com/favicon.ico`,
  `https://www.bing.com/favicon.ico`, `https://brave.com/favicon.ico`,
  `https://kagi.com/favicon.ico`, and `https://www.ecosia.org/favicon.ico`.
  Onboarding never fetches these at runtime.
