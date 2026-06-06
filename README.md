# CueCam

A premium teleprompter for creators. Record yourself while your script scrolls right
over the live camera, or read on a themed full-screen prompter. Everything runs
on-device. No server, no accounts, no ongoing costs.

Built in SwiftUI with a StoreKit 2 one-time unlock.

## Features
- **Camera mode** - the script scrolls over the live camera while you record. The text
  is an on-screen overlay only; it is never burned into your video. Front/back camera,
  one-tap record, saves straight to Photos.
- **Screen mode** - read on a clean, themed full-screen prompter.
- **Voice-follow scrolling (Pro)** - the words advance as you speak, using on-device
  speech recognition. Private and free to run.
- **Themes & fonts (Pro)** - five color themes, four typefaces.
- Auto-hiding controls, a 3-2-1 countdown, a progress bar, adjustable speed and text
  size, mirror mode for beam-splitter rigs, and haptics throughout.
- Scripts are stored locally as JSON.

## Business model
- Free: up to 3 saved scripts, screen + camera mode, classic theme.
- Pro: a one-time purchase (default $6.99) unlocks unlimited scripts, voice-follow,
  all themes/fonts, and mirror mode.
- Product ID: `com.rajannagar.CueCam.pro`

## Run it
1. Open `CueCam.xcodeproj` in Xcode.
2. Your signing team is already set. Pick your iPhone as the destination and press Run.
3. Camera, microphone, and speech features need a real device - they do not work in the
   Simulator.

## Test the paywall (before going live)
1. Product menu > Scheme > Edit Scheme… > Run > Options.
2. Set "StoreKit Configuration" to `Products.storekit`.
3. Run. "Unlock Pro" now completes a sandbox purchase.

## Submit to the App Store
1. In App Store Connect, create the app and an In-App Purchase:
   - Type: Non-Consumable
   - Product ID: `com.rajannagar.CueCam.pro`
   - Price: your choice
2. In Xcode: Product > Archive, then Distribute App > App Store Connect.
3. Add screenshots and description, then submit for review.

## Project layout
```
CueCam/
  CueCamApp.swift      App entry
  Models/                       Script, local store, themes & fonts
  Store/PurchaseManager.swift   StoreKit 2 unlock
  Prompter/                     Engine, camera, voice-follow, shared canvas + settings
  Views/                        List, Editor, Teleprompter (screen), Camera, Paywall, Settings
  Theme/Theme.swift             Colors, ambient background, card style
  Assets.xcassets               App icon + accent color
Products.storekit               Local StoreKit test config
```
