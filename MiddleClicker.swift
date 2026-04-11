import Cocoa
import CoreGraphics

// Global state
var isMiddleClicking = false
var globalEventTap: CFMachPort?
var activeModifier: CGEventFlags = .maskSecondaryFn

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
            if let newEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: event.location, mouseButton: .center) {
                newEvent.timestamp = event.timestamp
                return Unmanaged.passRetained(newEvent)
            }
        } else if type == .leftMouseDown {
            // Stuck state: got a new mouseDown while supposedly mid-drag.
            // Send the missing otherMouseUp, then fall through to normal handling.
            isMiddleClicking = false
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

// Draw a mouse icon with highlighted middle button for the menu bar
func makeMenuBarIcon() -> NSImage {
    let size = NSSize(width: 14, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
        let w = rect.width, h = rect.height
        NSColor.black.setStroke()
        NSColor.black.setFill()

        // Mouse body — rounded rectangle
        let body = NSBezierPath(roundedRect: NSRect(x: 1, y: 0, width: w - 2, height: h - 1), xRadius: 5, yRadius: 5)
        body.lineWidth = 1.4
        body.stroke()

        // Divider line between left and right buttons
        let dividerY = h * 0.55
        let left = NSBezierPath()
        left.move(to: NSPoint(x: 1, y: dividerY))
        left.line(to: NSPoint(x: w - 1, y: dividerY))
        left.lineWidth = 0.8
        left.stroke()

        // Middle button — small filled rectangle at top center
        let btnW: CGFloat = 3.5
        let btnH: CGFloat = 5
        let btnRect = NSRect(x: (w - btnW) / 2, y: dividerY, width: btnW, height: btnH)
        let btn = NSBezierPath(roundedRect: btnRect, xRadius: 1, yRadius: 1)
        btn.fill()

        return true
    }
    return image
}

// Application Delegate to handle Menu Bar
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var modifierMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore saved modifier key
        if let savedKey = UserDefaults.standard.string(forKey: "modifierKey"),
           let option = modifierOptions.first(where: { $0.key == savedKey }) {
            activeModifier = option.flag
        }

        // Create Menu Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = makeMenuBarIcon()
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

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
app.delegate = delegate
app.setActivationPolicy(.accessory) // Hides from Dock
app.run()
