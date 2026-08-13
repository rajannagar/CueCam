# CueCam

A calm, reader-style teleprompter for creators and speakers. Read your script on a warm,
book-like screen, or record yourself while it scrolls over the live camera. Everything
runs on-device. No server, no accounts, no ongoing costs.

Built in SwiftUI with a StoreKit 2 one-time unlock.

**Live on the App Store since June 10, 2026:**
[CueCam: Teleprompter](https://apps.apple.com/us/app/cuecam-teleprompter/id6777586422) (app ID 6777586422).

## Features
- **Screen mode** read on a calm, full-screen prompter that looks like an e-reader.
- **Camera mode** the script scrolls over the live camera while you record. The text is
  an on-screen overlay only; it is never burned into your video. Front/back camera,
  one-tap record, saves straight to Photos, then share to TikTok/Instagram.
- **Reader themes** six light and dark appearances (Paper, Ivory, Sepia, Charcoal,
  Classic, Night) that re-skin the whole app, so it stays easy on the eyes.
- **Typography** seven fonts (serif default), a bold toggle, adjustable text size,
  custom text color, and an adjustable reading-line position.
- **Voice-follow** the words advance as you speak, using on-device speech recognition.
- **Karaoke highlight** the line you are reading stays bright while the rest dims.
- **Hands-free volume control** use the volume buttons to play/pause (screen) or
  start/stop recording (camera).
- **Aspect-ratio guides** frame for 9:16, 1:1, or 16:9 with a rule-of-thirds overlay.
- **Templates** starter scripts (YouTube intro, TikTok hook, best man speech, vows,
  sales pitch, product demo).
- **Share a script as PDF**, a 3-2-1 countdown, mirror mode for beam-splitter rigs,
  smooth 120Hz scrolling, and an app-icon picker (with optional match-to-theme).
- Scripts are stored locally as JSON.

## Free vs Pro
- **Free:** up to 3 scripts, Paper theme, 3 fonts (Serif/Rounded/System), countdown,
  camera recording, templates, PDF/share, aspect guides, the app-icon picker.
- **Pro (one-time, default $6.99):** unlimited scripts, all 6 themes, all 7 fonts,
  custom text color, voice-follow, karaoke highlight, mirror mode, and hands-free
  volume control.
- In-app purchase product ID: `com.rajannagar.CueCam.pro`

## Run it
1. Open `CueCam.xcodeproj` in Xcode.
2. The signing team is already set. Pick your iPhone as the destination and press Run.
3. Camera, microphone, speech, and volume-button features need a real device; they do
   not work in the Simulator.

## Test the paywall (before going live)
1. Product menu > Scheme > Edit Scheme > Run > Options.
2. Set "StoreKit Configuration" to `Products.storekit`.
3. Run. "Unlock Pro" now completes a sandbox purchase. Reset via Debug > StoreKit >
   Manage Transactions. There is also a DEBUG-only Pro toggle in Settings.

## App Store status
- Live since June 10, 2026 as version 1.0. The CueCam Pro unlock
  (`com.rajannagar.CueCam.pro`, $6.99) is approved and on sale.
- The privacy policy is served by GitHub Pages from this repo's main branch:
  https://rajannagar.github.io/CueCam/privacy.html. Pushing to main updates the
  live page. Support URL on the listing: https://www.softcomputers.ca/contact
- Not on the listing yet: the app preview video (`marketing/CueCam-preview.mov`,
  polish it first per `STORE_LISTING.md`) and the `02-voice` iPad screenshot.
- Note: the shipped 1.0 binary predates `PrivacyInfo.xcprivacy`; the manifest
  ships with the next update.

## Ship an update
1. Bump `MARKETING_VERSION` in the project (build number restarts per version).
2. Archive and upload: Product > Archive, then Distribute App > App Store
   Connect (or `xcodebuild` with the ASC API key).
3. In App Store Connect, create the new version, paste the What's New text,
   attach the build, and Submit for Review.

## Project layout
```
CueCam/
  CueCamApp.swift               App entry, splash, theme/palette injection
  Models/                       Script, local store, reader themes, fonts, templates
  Store/PurchaseManager.swift   StoreKit 2 one-time unlock
  Prompter/                     Engine, camera, voice-follow, volume buttons,
                                aspect guides, shared canvas + preferences
  Views/                        List, Editor, Teleprompter (screen), Camera, Paywall,
                                Settings, Templates, App icons, Splash
  Theme/                        ThemeManager + ReaderPalette, AppBackground, card style
  Assets.xcassets               App icon + 3 alternate icons + accent color
Products.storekit               Local StoreKit test config
STORE_LISTING.md                App Store copy, keywords, screenshot captions, preview script
```
