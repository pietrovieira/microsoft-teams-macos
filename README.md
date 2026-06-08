# Microsoft Teams - Unofficial for macOS

A lightweight, unofficial Microsoft Teams desktop client for macOS built with Flutter. Uses a WebView to load Teams directly in a dedicated native window with full Apple Notification Center integration.

## Features

- Native macOS window (not a browser tab)
- Full Microsoft Teams web experience
- Apple Notification Center support
- Custom user agent for compatibility
- **Software rendering mode** for GPU compatibility issues
- **Automatic image fix** — detects and reloads broken profile pictures and attachments
- **Keep-alive injection** — prevents Teams from marking you as away
- **Media permissions** — camera and microphone access handled natively
- Lightweight (~48MB)

## Why this exists

The official Microsoft Teams desktop app for macOS can be heavy, slow, and resource-intensive. This alternative gives you the full Teams experience in a minimal native wrapper without the bloat.

## Requirements

- macOS 10.14 or later
- Microsoft Teams account

## Installation

### Option 1: Download the latest release

Download the latest `.app` bundle from the [Releases](https://github.com/pietrovieira/microsoft-teams-macos/releases) page.

### Option 2: Build from source

```bash
git clone https://github.com/pietrovieira/microsoft-teams-macos.git
cd microsoft-teams-macos
flutter pub get
flutter build macos
open build/macos/Build/Products/Release/
```

You need [Flutter SDK](https://docs.flutter.dev/get-started/install/macos) installed.

## How it works

This app loads `https://teams.cloud.microsoft/` inside a native WebKit WebView with a Chrome user agent for full compatibility. It requests notification permissions on launch so Teams alerts appear in the macOS Notification Center.

## Author

Built with 💙 by [Pietro Vieira](https://github.com/pietrovieira) — macOS developer and Teams power user.

## Disclaimer

This is an **unofficial** third-party client. Not affiliated with or endorsed by Microsoft Corporation.
