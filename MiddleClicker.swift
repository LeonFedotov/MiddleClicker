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
    ("Command", .maskCommand, "command"),
    ("Shift", .maskShift, "shift"),
]

// The event tap callback function
func callback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    // Re-enable the tap if macOS disabled it (happens under system load)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
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
            // Stuck state: got a new mouseDown while supposedly mid-drag — reset
            isMiddleClicking = false
        }
        // If we are middle clicking, swallow strictly related left-mouse events
        return nil
    }

    // 2. Detect the Start of a Click (Fn + Left Mouse Down)
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
            button.title = "M"
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

        // Request Accessibility Permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "MiddleClicker needs Accessibility access"
            alert.informativeText = "Enable it in System Settings > Privacy & Security > Accessibility, then relaunch."
            alert.runModal()
        }

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
