# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MiddleClicker is a macOS menu-bar utility that converts Fn+Click into middle-mouse-button events. It targets 3D apps (Blender, Maya, CAD) where middle-click drag is essential. It runs as a background accessory (no Dock icon, `LSUIElement = true`).

## Build

```bash
./build.sh
```

This compiles `MiddleClicker.swift` with `swiftc`, produces `MiddleClicker.app` bundle, ad-hoc codesigns it, and packages it into `MiddleClicker_Installer.dmg`. No Xcode project, no SPM, no dependencies.

To compile only (skip DMG packaging):

```bash
swiftc MiddleClicker.swift -o MiddleClicker.app/Contents/MacOS/MiddleClicker
```

## Architecture

Single-file app (`MiddleClicker.swift`, ~100 lines). No tests, no linter, no package manager.

- **`callback`** -- `CGEventTap` callback. Intercepts `leftMouseDown/Up/Dragged`. When Fn (`.maskSecondaryFn`) is held during `leftMouseDown`, swallows it and posts `otherMouseDown` (button 3) instead. Tracks drag state via global `isMiddleClicking` bool.
- **`AppDelegate`** -- Sets up the menu-bar status item ("M"), requests Accessibility permissions (`AXIsProcessTrustedWithOptions`), creates and registers the `CGEventTap` on the session event tap.
- **Entry point** -- Bottom of file. Creates `NSApplication`, sets `.accessory` activation policy, runs the app.

## Key constraints

- Requires **Accessibility permissions** (System Settings > Privacy & Security > Accessibility). Without it, the event tap creation fails and the app exits.
- The app is **unsigned** (ad-hoc signed). First launch requires right-click > Open.
- Event replacement is same-length byte-level: original event is swallowed (`return nil`) and a new `CGEvent` with `.center` button is returned via `Unmanaged.passRetained`.
