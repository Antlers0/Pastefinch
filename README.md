# Pastefinch

Pastefinch is a lightweight macOS menu bar utility for clipboard history and screenshot history.

Repository: https://github.com/Antlers0/Pastefinch

## Features

- Menu bar panel with tabs for **Clipboard** and **Screenshots**
- Global hotkey: `Option + Command + V` to show or hide the panel
- Clipboard history for text, images, and files (up to 200 items)
- Screenshot history from saved system screenshots and clipboard captures (up to 100 items)
- Search, single-item delete, and clear history
- Click outside the panel to dismiss
- Local-only storage under `~/Library/Application Support/Pastefinch/`
- Clearing screenshot history does **not** delete original screenshot files on disk

## Requirements

- macOS 13.0 or later
- Xcode 15 or later (for building from source)

## Build

Open `ClipShotHistory.xcodeproj` in Xcode, select the **ClipShotHistory** scheme and **My Mac**, then run (`Command + R`).

Or build from the command line:

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

The app bundle is written to:

```text
DerivedData/Build/Products/Release/Pastefinch.app
```

## Package

```bash
ditto -c -k --keepParent \
  DerivedData/Build/Products/Release/Pastefinch.app \
  Pastefinch.zip
```

## Distribution

Upload `Pastefinch.zip` to a [GitHub Release](https://github.com/Antlers0/Pastefinch/releases).

Unsigned builds may be blocked by Gatekeeper. Users can open the app via Finder context menu → **Open**. For wider distribution, sign with a Developer ID certificate and notarize the build.

## Privacy

All history is stored locally on the Mac. Pastefinch does not sync data to the cloud. Do not rely on it as a password manager; clipboard contents are stored in plain form.

## License

Copyright © 2026 Pastefinch. All rights reserved.
