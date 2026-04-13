# MiddleClicker

A lightweight macOS menu-bar utility that turns **Modifier + Click** into a **Middle Click**.

Built for 3D apps like Blender, Maya, and CAD software where middle-mouse drag is essential for viewport navigation — but your trackpad doesn't have one.

## Features

- **Configurable modifier key** — choose between Fn, Control, Option, Command, or Shift from the menu bar
- **Enable/disable toggle** — turn middle-click emulation on or off without quitting
- **Live menu bar icon** — shows current state at a glance:
  - Idle: mouse outline
  - Middle-click active: filled middle button
  - Left drag (3-finger): filled left button
  - Disabled: mouse with prohibition sign
- **Native trackpad support** — works with physical clicks and holds, including continuous middle-mouse drags
- **Auto-recovery** — re-enables itself if macOS disables the event tap under load
- **Persistent settings** — modifier key and enabled state are saved across restarts

## Install

### Homebrew

```bash
brew tap LeonFedotov/middleclicker
brew install --cask middleclicker
```

### Download

1. Grab `MiddleClicker_Installer.dmg` from the [Releases](https://github.com/LeonFedotov/MiddleClicker/releases) page
2. Open the DMG and drag **MiddleClicker** into Applications
3. First launch: right-click the app and select **Open** (it's unsigned)
4. Grant **Accessibility** permissions when prompted

### Build from source

```bash
git clone https://github.com/LeonFedotov/MiddleClicker.git
cd MiddleClicker
./build.sh
```

This compiles the app, codesigns it ad-hoc, and packages `MiddleClicker_Installer.dmg`.

## Usage

Once running, you'll see a mouse icon in your menu bar. Click it to:

- **Enabled** — toggle middle-click emulation on/off
- **Modifier Key** — pick which key activates middle-click (default: Fn)
- **Quit MiddleClicker**

Hold your chosen modifier and click/drag on the trackpad to emulate a middle-mouse button.

## Troubleshooting

### Accessibility permission stuck / won't re-prompt

If you moved the app or rebuilt it, macOS may have a stale permission entry. Reset it:

```bash
tccutil reset Accessibility com.opensource.MiddleClicker
```

Then relaunch — the permission prompt will appear again.

### Icon stays in "left drag" state briefly after lifting fingers

This is macOS three-finger drag lock — the OS intentionally holds the drag for ~0.5s after you lift your fingers so you can reposition without dropping. The `leftMouseUp` event doesn't fire until macOS decides the drag is over. Starting any new interaction cancels the delay immediately.

### App stopped responding to clicks

macOS can disable event taps under heavy system load. The app auto-recovers from this, but if it persists, quit and relaunch.

## How it works

A `CGEventTap` intercepts `leftMouseDown` events. When the selected modifier key is held, the left click is swallowed and replaced with an `otherMouseDown` (button 3) event. Drag and mouse-up events are similarly translated while the middle-click state is active.

## TODO

- [ ] Mid-drag modifier activation — press the modifier key during an existing 3-finger drag to switch it into a middle-click on the fly, without needing to start a new gesture

## License

MIT
