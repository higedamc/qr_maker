# QR Maker

macOS menu bar utility for generating QR codes from text input. Designed for securely transmitting Bitcoin transaction data and arbitrary text across air-gapped devices.

## Features

- Menu bar resident app (no Dock icon)
- Real-time QR code generation with error correction level H
- Global keyboard shortcut (configurable)
- Automatic clipboard import on activation
- Offline-only: no network communication

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

## Build

```bash
./scripts/build.sh
```

Or manually:

```bash
xcodegen generate
xcodebuild -project QRMaker.xcodeproj -scheme QRMaker -configuration Release build
```

The `.app` bundle is output to `build/Build/Products/Release/QRMaker.app`.

## Release Security

- Release builds are expected to use a reproducible SwiftPM lockfile (`Package.resolved`) committed to git.
- Release signing should include Hardened Runtime and timestamped code signatures.
- Distribution artifacts should be notarized before external sharing.

## Directory Structure

```
qr_maker/
├── project.yml                          # xcodegen configuration
├── QRMaker/
│   ├── App/
│   │   ├── QRMakerApp.swift             # @main entry point
│   │   └── AppDelegate.swift            # NSStatusItem, NSPopover, lifecycle
│   ├── Features/
│   │   ├── Generator/
│   │   │   ├── Views/
│   │   │   │   ├── GeneratorView.swift
│   │   │   │   └── QRCodeImageView.swift
│   │   │   └── GeneratorViewModel.swift
│   │   └── Settings/
│   │       └── Views/
│   │           └── ShortcutSettingsView.swift
│   ├── Core/
│   │   ├── Services/
│   │   │   ├── QRCodeService.swift
│   │   │   └── ClipboardService.swift
│   │   └── Shortcuts/
│   │       └── ShortcutNames.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       └── Info.plist
├── scripts/
│   └── build.sh
└── README.md
```

## Architecture

Feature-based clean architecture with MVVM pattern.

- **App**: Application lifecycle and system integration (AppDelegate, NSStatusItem)
- **Features**: Self-contained feature modules (Generator, Settings)
- **Core**: Shared services and utilities (QRCodeService, ClipboardService, KeyboardShortcuts)

## Usage

1. Launch QR Maker - the app appears as a QR code icon in the menu bar
2. Click the icon or press the configured shortcut to open the popover
3. Text from the clipboard is automatically loaded (if enabled)
4. Type or paste text to generate a QR code in real-time
5. Configure the global shortcut via the settings gear icon

## License

MIT
