import Cocoa
import CoreGraphics

// Global state
var isMiddleClicking = false
var isEnabled = true
var globalEventTap: CFMachPort?
var activeModifier: CGEventFlags = .maskSecondaryFn
weak var appDelegate: AppDelegate?

// Modifier key options: display name, CGEventFlags value, UserDefaults key string
let modifierOptions: [(name: String, flag: CGEventFlags, key: String)] = [
    ("Fn", .maskSecondaryFn, "fn"),
    ("Control", .maskControl, "control"),
    ("Option", .maskAlternate, "option"),
    ("Command (may conflict with macOS)", .maskCommand, "command"),
    ("Shift", .maskShift, "shift"),
]

// The event tap callback function
func callback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    // Re-enable the tap if macOS disabled it (happens under system load)
    if type == .tapDisabledByTimeout {
        if let tap = globalEventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    // Pass through everything when disabled
    if !isEnabled {
        return Unmanaged.passUnretained(event)
    }

    // 1. Handle Dragging and Mouse Up if we are currently in a "Middle Click" state
    if isMiddleClicking {
        if type == .leftMouseDragged {
            // Create a new Middle Mouse Dragged event
            if let newEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDragged, mouseCursorPosition: event.location, mouseButton: .center) {
                newEvent.timestamp = event.timestamp
                return Unmanaged.passRetained(newEvent)
            }
        } else if type == .leftMouseUp {
            // End the middle click
            isMiddleClicking = false
            DispatchQueue.main.async { appDelegate?.updateIcon() }
            if let newEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: event.location, mouseButton: .center) {
                newEvent.timestamp = event.timestamp
                return Unmanaged.passRetained(newEvent)
            }
        } else if type == .leftMouseDown {
            // Stuck state: got a new mouseDown while supposedly mid-drag.
            // Send the missing otherMouseUp, then fall through to normal handling.
            isMiddleClicking = false
            DispatchQueue.main.async { appDelegate?.updateIcon() }
            if let upEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: event.location, mouseButton: .center) {
                upEvent.timestamp = event.timestamp
                upEvent.post(tap: .cgSessionEventTap)
            }
            // Don't return — fall through to check if this new click starts a middle-click
        } else {
            return nil
        }
    }

    // 2. Detect the Start of a Click (Modifier + Left Mouse Down)
    if type == .leftMouseDown {
        let flags = event.flags
        if flags.contains(activeModifier) {
            isMiddleClicking = true
            DispatchQueue.main.async { appDelegate?.updateIcon() }

            // Create a new Middle Mouse Down event
            if let newEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown, mouseCursorPosition: event.location, mouseButton: .center) {
                newEvent.timestamp = event.timestamp
                return Unmanaged.passRetained(newEvent)
            }
            // Swallow the original left click
            return nil
        }
    }

    // Pass all other events through unchanged
    return Unmanaged.passUnretained(event)
}

// Icon states for the menu bar
enum IconState { case idle, active, disabled }

func makeMenuBarIcon(_ state: IconState) -> NSImage {
    let size = NSSize(width: 14, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
        let w = rect.width, h = rect.height
        NSColor.black.setStroke()
        NSColor.black.setFill()

        // Mouse body — rounded rectangle
        let bodyRect = NSRect(x: 1, y: 0, width: w - 2, height: h - 1)
        let body = NSBezierPath(roundedRect: bodyRect, xRadius: 5, yRadius: 5)
        body.lineWidth = 1.4
        body.stroke()

        // Divider line between left and right buttons
        let dividerY = h * 0.55
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 1, y: dividerY))
        divider.line(to: NSPoint(x: w - 1, y: dividerY))
        divider.lineWidth = 0.8
        divider.stroke()

        // Middle button — filled when active, outline when idle, hidden when disabled
        let btnW: CGFloat = 3.5
        let btnH: CGFloat = 5
        let btnRect = NSRect(x: (w - btnW) / 2, y: dividerY, width: btnW, height: btnH)
        let btn = NSBezierPath(roundedRect: btnRect, xRadius: 1, yRadius: 1)
        switch state {
        case .active:
            btn.fill()
        case .idle:
            btn.lineWidth = 0.8
            btn.stroke()
        case .disabled:
            break
        }

        // Prohibition sign when disabled — circle with diagonal line
        if state == .disabled {
            let center = NSPoint(x: w / 2, y: (h - 1) / 2)
            let radius: CGFloat = min(w, h) / 2 - 0.5
            let circle = NSBezierPath(ovalIn: NSRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            circle.lineWidth = 1.4
            circle.stroke()
            let slash = NSBezierPath()
            let offset = radius * 0.707 // cos(45°)
            slash.move(to: NSPoint(x: center.x - offset, y: center.y + offset))
            slash.line(to: NSPoint(x: center.x + offset, y: center.y - offset))
            slash.lineWidth = 1.4
            slash.stroke()
        }

        return true
    }
    return image
}

// Application Delegate to handle Menu Bar
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var modifierMenuItems: [NSMenuItem] = []
    var enabledMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore saved modifier key
        if let savedKey = UserDefaults.standard.string(forKey: "modifierKey"),
           let option = modifierOptions.first(where: { $0.key == savedKey }) {
            activeModifier = option.flag
        }

        // Restore enabled state
        isEnabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true

        // Create Menu Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        let menu = NSMenu()

        // Enabled toggle
        enabledMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledMenuItem.state = isEnabled ? .on : .off
        menu.addItem(enabledMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Modifier key submenu
        let modifierSubmenu = NSMenu()
        for (index, option) in modifierOptions.enumerated() {
            let item = NSMenuItem(title: option.name, action: #selector(modifierSelected(_:)), keyEquivalent: "")
            item.tag = index
            item.state = option.flag == activeModifier ? .on : .off
            modifierSubmenu.addItem(item)
            modifierMenuItems.append(item)
        }
        let modifierItem = NSMenuItem(title: "Modifier Key", action: nil, keyEquivalent: "")
        modifierItem.submenu = modifierSubmenu
        menu.addItem(modifierItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MiddleClicker", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu

        // Prompt for Accessibility permissions if not yet granted (the tap will fail without it)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        AXIsProcessTrustedWithOptions(options)

        // Create the Event Tap
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(eventMask),
                                          callback: callback,
                                          userInfo: nil) else {
            let alert = NSAlert()
            alert.messageText = "MiddleClicker failed to start"
            alert.informativeText = "Could not create event tap. Make sure Accessibility access is granted and relaunch."
            alert.runModal()
            NSApplication.shared.terminate(self)
            return
        }

        globalEventTap = tap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func updateIcon() {
        let state: IconState = !isEnabled ? .disabled : isMiddleClicking ? .active : .idle
        let icon = makeMenuBarIcon(state)
        icon.isTemplate = true
        statusItem.button?.image = icon
    }

    @objc func toggleEnabled() {
        isEnabled.toggle()
        UserDefaults.standard.set(isEnabled, forKey: "enabled")
        enabledMenuItem.state = isEnabled ? .on : .off
        if !isEnabled { isMiddleClicking = false }
        updateIcon()
    }

    @objc func modifierSelected(_ sender: NSMenuItem) {
        guard sender.tag >= 0 && sender.tag < modifierOptions.count else { return }
        let option = modifierOptions[sender.tag]
        activeModifier = option.flag
        UserDefaults.standard.set(option.key, forKey: "modifierKey")
        for item in modifierMenuItems {
            item.state = .off
        }
        sender.state = .on
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}

// Main Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
appDelegate = delegate
app.delegate = delegate
app.setActivationPolicy(.accessory) // Hides from Dock
app.run()
