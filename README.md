# MiddleClicker

A lightweight macOS menu-bar utility that turns **Modifier + Click** into a **Middle Click**.

Built for 3D apps like Blender, Maya, and CAD software where middle-mouse drag is essential for viewport navigation — but your trackpad doesn't have one.

## Features

- **Configurable modifier key** — choose between Fn, Control, Option, Command, or Shift from the menu bar
- **Native trackpad support** — works with physical clicks and holds, including continuous middle-mouse drags
- **Lightweight** — single-file Swift app, runs as a background accessory (no Dock icon)
- **Auto-recovery** — re-enables itself if macOS disables the event tap under load

## Install

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

Once running, you'll see an **M** in your menu bar. Click it to:

- **Modifier Key** — pick which key activates middle-click (default: Fn). Your choice is saved across restarts.
- **Quit MiddleClicker**

Hold your chosen modifier and click/drag on the trackpad to emulate a middle-mouse button.

## Troubleshooting

### Accessibility permission stuck / won't re-prompt

If you moved the app or rebuilt it, macOS may have a stale permission entry. Reset it:

```bash
tccutil reset Accessibility com.opensource.MiddleClicker
```

Then relaunch — the permission prompt will appear again.

### App stopped responding to clicks

macOS can disable event taps under heavy system load. The app auto-recovers from this, but if it persists, quit and relaunch.

## How it works

A `CGEventTap` intercepts `leftMouseDown` events. When the selected modifier key is held, the left click is swallowed and replaced with an `otherMouseDown` (button 3) event. Drag and mouse-up events are similarly translated while the middle-click state is active.

## License

MIT
