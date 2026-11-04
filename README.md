<div align="center">

<img src="ClipShotHistory/Resources/PastefinchIcon.png" width="120" alt="Pastefinch">

# Pastefinch

**Clipboard + screenshot history for your Mac menu bar.**

[English](README.md) · [中文](README.zh-CN.md)

<br>

[![macOS](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](https://github.com/Antlers0/Pastefinch)
[![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)](https://github.com/Antlers0/Pastefinch)
[![Release](https://img.shields.io/github/v/release/Antlers0/Pastefinch?color=2ea44f)](https://github.com/Antlers0/Pastefinch/releases)
[![Downloads](https://img.shields.io/github/downloads/Antlers0/Pastefinch/total?color=0969da)](https://github.com/Antlers0/Pastefinch/releases)

<br>

[`Download`](https://github.com/Antlers0/Pastefinch/releases) · [`Source`](#build-from-source) · [`Privacy`](#privacy)

</div>

---

## Why Pastefinch

macOS only keeps the latest clipboard item. Pastefinch quietly remembers what you copied and the screenshots you took — then brings them back with one hotkey.

| | Capability | Detail |
| :---: | :--- | :--- |
| 📋 | Clipboard | Text, images, files — searchable history |
| 📌 | Pin | Keep favorites above the fold; protected from clear/trim |
| 🎨 | Color preview | Detects `#RGB` / `rgb()` with swatch + HEX/RGB copy |
| 🐦 | Chirp feedback | Menu-bar bird bounces on capture/copy |
| 📊 | Today stats | Live clipboard + screenshot capture counts |
| 🖼️ | Screenshots | Saved shots + clipboard captures |
| ⌨️ | Hotkey | `⌥⌘V` to open or close the panel |
| 🧹 | Cleanup | Delete one item, clear all, auto trim |
| 🔒 | Private | Local storage only, no cloud sync |

---

## Install

1. Grab the latest **`Pastefinch.zip`** from [Releases](https://github.com/Antlers0/Pastefinch/releases)
2. Unzip and drag **`Pastefinch.app`** into **Applications**
3. Launch it — look for the bird icon in the menu bar

> **Gatekeeper tip:** If macOS blocks an unsigned build, right-click the app in Finder → **Open**.

---

## Build from source

```bash
xcodebuild \
  -project ClipShotHistory.xcodeproj \
  -scheme ClipShotHistory \
  -configuration Release \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```text
DerivedData/Build/Products/Release/Pastefinch.app
```

```bash
ditto -c -k --keepParent \
  DerivedData/Build/Products/Release/Pastefinch.app \
  Pastefinch.zip
```

**Requirements:** macOS 13+ · Xcode 15+

---

## Privacy

All history lives on your Mac:

```text
~/Library/Application Support/Pastefinch/
```

No accounts. No analytics. No cloud.  
Clipboard data is stored in plain form — don’t treat Pastefinch as a password vault.  
Clearing screenshot history never deletes the original files on disk.

---

## License

Copyright © 2026 Pastefinch. All rights reserved.
