# Teleprompter Pro

A premium, on-device teleprompter for iPhone and iPad. No server, no accounts, no
ongoing costs. Built in SwiftUI with a StoreKit 2 one-time unlock.

## What it does
- Write or paste a script, hit play, and read while the words scroll at a pace you control.
- Auto-hiding controls for immersive reading, a 3-2-1 countdown, and a progress bar.
- Adjustable scroll speed and text size. Mirror mode for beam-splitter camera rigs (Pro).
- Everything is stored locally on the device.

## Business model
- Free: up to 3 saved scripts.
- Pro: a one-time purchase (default $6.99) unlocks unlimited scripts, mirror mode, and themes.
- Product ID: `com.rajannagar.TeleprompterPro.pro`

## Run it
1. Open `TeleprompterPro.xcodeproj` in Xcode.
2. If Xcode offers to install the matching iOS Simulator runtime, accept it (or just run on your own iPhone).
3. Pick a simulator or your device and press Run.

## Test the paywall (before going live)
StoreKit testing lets you tap "Unlock Pro" without real money:
1. Product menu > Scheme > Edit Scheme… > Run > Options.
2. Set "StoreKit Configuration" to `Products.storekit`.
3. Run. The Unlock button now completes a sandbox purchase.

## Submit to the App Store
1. Select the project > target > Signing & Capabilities, and choose your Team.
2. In App Store Connect, create the app and add an In-App Purchase:
   - Type: Non-Consumable
   - Product ID: `com.rajannagar.TeleprompterPro.pro`
   - Price: your choice (the code shows whatever App Store Connect returns)
3. In Xcode: Product > Archive, then Distribute App > App Store Connect.
4. Fill in screenshots, description, and submit for review.

## Project layout
```
TeleprompterPro/
  TeleprompterProApp.swift      App entry
  Models/                       Script + local JSON store
  Store/PurchaseManager.swift   StoreKit 2 unlock
  Views/                        List, Editor, Teleprompter, Paywall, Settings
  Theme/Theme.swift             Colors, ambient background, card style
  Assets.xcassets               App icon + accent color
Products.storekit               Local StoreKit test config
```
