# MacOS SimpleTaskBar liquidGlass

Menu bar task tracker for macOS 26+ with Liquid Glass UI, local persistence, deadlines, and notifications.

## Requirements

- macOS 26 (Tahoe) or later
- Swift 6.2+ toolchain

## Build

```bash
./scripts/build-app.sh Resources/icon.png
```

Output: `dist/TaskBar.app`

## Install

Download `TaskBar.app.zip` from [Releases](https://github.com/vivaladev/MacOS-SimpleTaskBar-liquidGlass/releases), unzip, move to Applications, then open.

If macOS blocks launch: Right-click → Open.

## Features

- One-off and daily tasks
- Deadline sorting (nearest first)
- Overdue highlighting
- Local storage in `~/Library/Application Support/TaskBar/tasks.json`
- macOS notifications at 09:00 on deadline day (daily tasks repeat every day)
