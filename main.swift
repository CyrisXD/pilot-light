import Cocoa
import IOKit
import IOKit.ps
import ServiceManagement

// Logged in + agent mode: lid close keeps Mac awake, low power on, screen off.
// Logged out / user switched away / app quits: normal lid-close sleep.

// Bump the suffix whenever pmsetCmds changes so existing installs are asked to reinstall.
let sudoersPath = "/etc/sudoers.d/pilotlight-v2"
let oldSudoers = ["/etc/sudoers.d/lidguard", "/etc/sudoers.d/pilotlight"]
// Support submenu: GitHub Sponsors for developers, Buy Me a Coffee for anyone without a GitHub account.
let supportLinks = [
    ("Sponsor on GitHub", "https://github.com/sponsors/CyrisXD"),
    ("Buy Me a Coffee", "https://buymeacoffee.com/FiRmVXOZh"),
]
// macOS 14+/newer models name the setting "powermode"; older ones "lowpowermode". -b/-c restore per power source.
let pmsetCmds = ["-a disablesleep 0", "-a disablesleep 1"] +
    ["powermode", "lowpowermode"].flatMap { k in ["-a", "-b", "-c"].flatMap { f in (0...2).map { "\(f) \(k) \($0)" } } }

@discardableResult
func run(_ path: String, _ args: [String]) -> String {
    let p = Process(), pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    p.standardOutput = pipe; p.standardError = pipe
    try? p.run(); p.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
}

// Only the exact commands whitelisted in sudoers; -n never prompts.
func pmset(_ cmd: String) { run("/usr/bin/sudo", ["-n", "/usr/bin/pmset"] + cmd.split(separator: " ").map(String.init)) }

// nil on Macs without a lid (Mac mini, iMac, Studio, Pro).
func lidClosed() -> Bool? {
    let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    defer { IOObjectRelease(root) }
    return IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? Bool
}
let hasLid = lidClosed() != nil

// Current Low Power Mode setting per power source, e.g. ["-b": 1, "-c": 0], from `pmset -g custom`.
// Key is whichever name this Mac uses; nil if the Mac has no Low Power Mode.
func powerModeSettings(_ out: String = run("/usr/bin/pmset", ["-g", "custom"])) -> (key: String, values: [String: Int])? {
    var key: String?, flag = "-c", values: [String: Int] = [:]
    for line in out.split(separator: "\n") {
        if line.hasPrefix("Battery Power") { flag = "-b" } else if line.hasPrefix("AC Power") { flag = "-c" }
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        if parts.count == 2, ["powermode", "lowpowermode"].contains(String(parts[0])), let v = Int(parts[1]) {
            key = String(parts[0]); values[flag] = v
        }
    }
    return key.map { ($0, values) }
}

// Tuning knobs for the lid-closed safety cutoffs.
// Low-battery cutoff from the menu; 0 = off.
var minBatteryPercent: Int { UserDefaults.standard.object(forKey: "minBattery") as? Int ?? 15 }
let maxThermal = ProcessInfo.ThermalState.serious

// Battery percent when running on battery, nil on AC.
func batteryPercent() -> Int? {
    let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    guard IOPSGetProvidingPowerSourceType(info).takeUnretainedValue() as String == kIOPSBatteryPowerValue else { return nil }
    for ps in IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef] {
        if let d = IOPSGetPowerSourceDescription(info, ps).takeUnretainedValue() as? [String: Any],
           let pct = d[kIOPSCurrentCapacityKey] as? Int { return pct }
    }
    return nil
}

func bailReason(_ thermal: ProcessInfo.ThermalState, _ battery: Int?, min: Int = minBatteryPercent) -> String? {
    if thermal.rawValue >= maxThermal.rawValue { return "too hot" }
    if let b = battery, b < min { return "battery \(b)%" }
    return nil
}

// Watts drawn from the battery plus full-charge energy; nil on AC (charging muddies the reading) or no battery.
func batteryDraw() -> (watts: Double, capacityWh: Double)? {
    let s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard s != 0 else { return nil }
    defer { IOObjectRelease(s) }
    var props: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(s, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let p = props?.takeRetainedValue() as? [String: Any] else { return nil }
    return batteryDraw(p)
}

// Apple Silicon reports MaxCapacity as a percent and the mAh in AppleRawMaxCapacity; Intel reports mAh in MaxCapacity.
func batteryDraw(_ p: [String: Any]) -> (watts: Double, capacityWh: Double)? {
    guard p["ExternalConnected"] as? Bool == false,
          let mv = p["Voltage"] as? Int,
          let ma = (p["InstantAmperage"] ?? p["Amperage"]) as? Int, ma < 0,
          let mah = (p["AppleRawMaxCapacity"] as? Int) ?? (p["MaxCapacity"] as? Int).flatMap({ $0 > 100 ? $0 : nil })
    else { return nil }
    return (Double(-ma * mv) / 1e6, Double(mah * mv) / 1e6)
}

func statLine(_ label: String, sum: Double, n: Int, capacityWh: Double) -> String {
    guard n > 0 else { return "\(label): measuring on battery…" }
    let w = sum / Double(n)
    let hours = capacityWh > 0 ? String(format: " · ~%.0f h battery", capacityWh / w) : ""
    return String(format: "%@: %.1f W%@", label, w, hours)
}

// Menu bar template glyphs on an 18 pt grid (from the design canvas): solid flame = on,
// outline = off, outline + dot = setup needed. macOS tints templates for light/dark menu bars.
let flamePath = "M9 1.75 C9 1.75 13.25 6.1 13.25 9.9 C13.25 12.35 11.35 14.25 9 14.25 C6.65 14.25 4.75 12.35 4.75 9.9 C4.75 6.1 9 1.75 9 1.75 Z"
let lidLine = "<line x1='3.5' y1='16.5' x2='14.5' y2='16.5' stroke='black' stroke-width='1.5' stroke-linecap='round'/>"
let flameOutline = "<path d='\(flamePath)' fill='none' stroke='black' stroke-width='1.5' stroke-linejoin='round'/>"
let glyphSVG = [
    "active": "<path d='\(flamePath) M9 8.2 C9 8.2 11 10.3 11 11.6 C11 12.7 10.1 13.4 9 13.4 C7.9 13.4 7 12.7 7 11.6 C7 10.3 9 8.2 9 8.2 Z' fill='black' fill-rule='evenodd'/>" + lidLine,
    "disabled": flameOutline + lidLine,
    "setup": flameOutline + lidLine + "<circle cx='14.6' cy='3.6' r='2.6' fill='black'/>",
]
let glyphs: [String: NSImage] = glyphSVG.mapValues { body in
    let svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 18 18' width='18' height='18'>\(body)</svg>"
    // SF Symbol fallback in case this macOS can't decode SVG into NSImage.
    let img = NSImage(data: Data(svg.utf8)) ?? NSImage(systemSymbolName: "flame", accessibilityDescription: nil)!
    img.size = NSSize(width: 18, height: 18)
    img.isTemplate = true
    return img
}

class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let toggle = NSMenuItem(title: "Keep awake when lid closed", action: #selector(flip), keyEquivalent: "")
    let install = NSMenuItem(title: "Install helper (admin)…", action: #selector(installHelper), keyEquivalent: "")
    let lowPowerItem = NSMenuItem(title: "Low Power Mode when lid closed", action: #selector(flipLowPower), keyEquivalent: "")
    let cutoffItem = NSMenuItem(title: "Sleep when battery below", action: nil, keyEquivalent: "")
    let loginItem = NSMenuItem(title: "Launch at login", action: #selector(flipLogin), keyEquivalent: "")
    var lowPower: Bool { UserDefaults.standard.object(forKey: "lowPower") as? Bool ?? true }
    var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true
    var sessionActive = true
    var wasClosed = false
    var bailed = false // slept for safety; stays asleep until lid opens
    let openStat = NSMenuItem(), closedStat = NSMenuItem()
    let resetStats = NSMenuItem(title: "Reset power averages", action: #selector(reset), keyEquivalent: "")
    var lastChange = Date(), lastSample = Date.distantPast
    var capacityWh = 0.0

    var armed: Bool { enabled && sessionActive && hasLid }
    var helperOK = FileManager.default.fileExists(atPath: sudoersPath)
    let powerKey = powerModeSettings()?.key

    func applicationDidFinishLaunching(_ n: Notification) {
        let menu = NSMenu()
        let cutoffs = NSMenu()
        for pct in [0, 10, 15, 20] {
            let i = NSMenuItem(title: pct == 0 ? "Off" : "\(pct)%", action: #selector(setCutoff), keyEquivalent: "")
            i.tag = pct; i.target = self
            cutoffs.addItem(i)
        }
        cutoffItem.submenu = cutoffs
        [install, toggle, lowPowerItem, loginItem, cutoffItem].forEach { $0.target = self; menu.addItem($0) }
        menu.addItem(.separator())
        let header = NSMenuItem(title: "Average power on battery", action: nil, keyEquivalent: "")
        header.isEnabled = false
        [header, openStat, closedStat].forEach { menu.addItem($0) }
        resetStats.target = self
        menu.addItem(resetStats)
        menu.addItem(.separator())
        let support = NSMenuItem(title: "Support", action: nil, keyEquivalent: "")
        support.image = NSImage(systemSymbolName: "heart", accessibilityDescription: nil)
        let supportMenu = NSMenu()
        for (i, link) in supportLinks.enumerated() {
            let s = NSMenuItem(title: link.0, action: #selector(openSupport), keyEquivalent: "")
            s.tag = i; s.target = self
            supportMenu.addItem(s)
        }
        support.submenu = supportMenu
        menu.addItem(support)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "q"))
        item.menu = menu

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sessionActive = false; self?.apply()
        }
        ws.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sessionActive = true; self?.apply()
        }
        // Posted on logout/shutdown/restart.
        ws.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { _ in restore() }

        restorePowerMode() // in case a previous run quit or crashed with the lid closed
        // ponytail: 2s poll of the lid sensor; swap for IOServiceAddInterestNotification if latency matters.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        apply()
    }

    func applicationWillTerminate(_ n: Notification) { restore() }

    func apply() {
        bailed = false
        // disablesleep has to be set before the lid closes (lid close sleeps instantly),
        // so while armed it also stops idle sleep with the lid open. Display sleep is unaffected.
        pmset(armed ? "-a disablesleep 1" : "-a disablesleep 0")
        if !armed { restorePowerMode() }
        refreshUI()
    }

    // Saves the user's per-source Low Power setting (persisted, survives a crash) then turns it on everywhere.
    func lowPowerOn() {
        guard let cur = powerModeSettings(), UserDefaults.standard.dictionary(forKey: "savedPowerMode") == nil else { return }
        UserDefaults.standard.set(cur.values, forKey: "savedPowerMode")
        pmset("-a \(cur.key) 1")
    }

    func tick() {
        let closed = lidClosed() ?? false
        if closed != wasClosed {
            wasClosed = closed
            lastChange = Date()
            if armed && closed {
                if lowPower { lowPowerOn() }
                run("/usr/bin/pmset", ["displaysleepnow"]) // also blanks any external display
            } else if armed {
                restorePowerMode()
                apply() // re-arm after a safety sleep
            }
            refreshUI()
        }
        // Safety cutoff: lid closed and too hot or battery low → let it sleep.
        if armed && closed && !bailed, let why = bailReason(ProcessInfo.processInfo.thermalState, batteryPercent()) {
            NSLog("Pilot Light: sleeping, \(why)")
            bailed = true
            pmset("-a disablesleep 0")
            run("/usr/bin/pmset", ["sleepnow"])
        }
        if Date().timeIntervalSince(lastSample) >= 30 { sample() }
    }

    // Running mean per lid state, persisted so it builds up over days.
    // Skips the first minute after a lid change (display/power mode still settling)
    // and lid-closed time when Pilot Light isn't holding the Mac awake.
    func sample() {
        lastSample = Date()
        guard Date().timeIntervalSince(lastChange) > 60, !wasClosed || (armed && !bailed),
              let b = batteryDraw() else { return }
        capacityWh = b.capacityWh
        let key = wasClosed ? "closed" : "open", d = UserDefaults.standard
        d.set(d.double(forKey: key + "Sum") + b.watts, forKey: key + "Sum")
        d.set(d.integer(forKey: key + "N") + 1, forKey: key + "N")
        refreshStats()
    }

    func refreshStats() {
        let d = UserDefaults.standard
        openStat.title = statLine("Lid open", sum: d.double(forKey: "openSum"), n: d.integer(forKey: "openN"), capacityWh: capacityWh)
        closedStat.title = statLine("Lid closed", sum: d.double(forKey: "closedSum"), n: d.integer(forKey: "closedN"), capacityWh: capacityWh)
    }

    @objc func reset() {
        let alert = NSAlert()
        alert.messageText = "Reset power averages?"
        alert.informativeText = "Lid-open and lid-closed averages start over from zero."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true) // menu bar apps aren't frontmost; without this the alert opens behind other windows
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        ["openSum", "openN", "closedSum", "closedN"].forEach(UserDefaults.standard.removeObject)
        refreshStats()
    }

    func refreshUI() {
        let helper = helperOK || !hasLid
        toggle.state = enabled && hasLid ? .on : .off
        toggle.isEnabled = hasLid
        toggle.title = hasLid ? "Keep awake when lid closed" : "This Mac has no lid, nothing to do"
        install.isHidden = helper
        lowPowerItem.isHidden = powerKey == nil || !hasLid
        item.button?.image = glyphs[!helper ? "setup" : armed ? "active" : "disabled"]
        item.button?.setAccessibilityLabel(!helper ? "Pilot Light: setup needed" : armed ? "Pilot Light: on" : "Pilot Light: off")
        item.button?.toolTip = armed ? "Lid close: stay awake, low power, screen off" : "Lid close: sleep"
        lowPowerItem.state = lowPower ? .on : .off
        cutoffItem.submenu?.items.forEach { $0.state = $0.tag == minBatteryPercent ? .on : .off }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        refreshStats()
    }

    @objc func flipLowPower() {
        UserDefaults.standard.set(!lowPower, forKey: "lowPower")
        refreshUI()
    }

    @objc func setCutoff(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "minBattery")
        refreshUI()
    }

    @objc func flipLogin() {
        let svc = SMAppService.mainApp
        do {
            try svc.status == .enabled ? svc.unregister() : svc.register()
        } catch {
            NSLog("Pilot Light: launch at login failed: \(error)")
        }
        if svc.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        refreshUI()
    }

    @objc func openSupport(_ sender: NSMenuItem) { NSWorkspace.shared.open(URL(string: supportLinks[sender.tag].1)!) }

    @objc func flip() {
        enabled.toggle()
        UserDefaults.standard.set(enabled, forKey: "enabled")
        apply()
    }

    @objc func installHelper() {
        let user = NSUserName()
        let rule = "\(user) ALL=(root) NOPASSWD: " + pmsetCmds.map { "/usr/bin/pmset \($0)" }.joined(separator: ", ") + "\n"
        let tmp = NSTemporaryDirectory() + "pilotlight.sudoers"
        try? rule.write(toFile: tmp, atomically: true, encoding: .utf8)
        let sh = "/usr/sbin/visudo -cf '\(tmp)' && /usr/bin/install -m 0440 -o root -g wheel '\(tmp)' \(sudoersPath) && /bin/rm -f \(oldSudoers.joined(separator: " "))"
        NSAppleScript(source: "do shell script \"\(sh)\" with administrator privileges")?.executeAndReturnError(nil)
        helperOK = FileManager.default.fileExists(atPath: sudoersPath)
        apply()
    }
}

// Puts back exactly what lowPowerOn() saved, per power source.
func restorePowerMode() {
    guard let saved = UserDefaults.standard.dictionary(forKey: "savedPowerMode") as? [String: Int],
          let key = powerModeSettings()?.key else { return }
    saved.forEach { pmset("\($0.key) \(key) \($0.value)") }
    UserDefaults.standard.removeObject(forKey: "savedPowerMode")
}

func restore() {
    pmset("-a disablesleep 0")
    restorePowerMode()
}

if CommandLine.arguments.contains("--selftest") {
    precondition(bailReason(.nominal, nil) == nil)
    precondition(bailReason(.fair, 50) == nil)
    precondition(bailReason(.serious, nil) == "too hot")
    precondition(bailReason(.critical, 80) == "too hot")
    precondition(bailReason(.nominal, 14, min: 15) == "battery 14%")
    precondition(bailReason(.nominal, 15, min: 15) == nil)
    precondition(bailReason(.nominal, 1, min: 0) == nil)
    precondition(statLine("Lid open", sum: 0, n: 0, capacityWh: 100) == "Lid open: measuring on battery…")
    precondition(statLine("Lid closed", sum: 48, n: 10, capacityWh: 96) == "Lid closed: 4.8 W · ~20 h battery")
    let custom = "Battery Power:\n lowpowermode         1\nAC Power:\n lowpowermode         0\n"
    precondition(powerModeSettings(custom)! == ("lowpowermode", ["-b": 1, "-c": 0]))
    precondition(powerModeSettings("AC Power:\n powermode 2\n")! == ("powermode", ["-c": 2]))
    precondition(powerModeSettings("AC Power:\n sleep 1\n") == nil)
    precondition(batteryDraw(["ExternalConnected": false, "Voltage": 12000, "InstantAmperage": -1000, "AppleRawMaxCapacity": 8000, "MaxCapacity": 100])! == (12.0, 96.0))
    precondition(batteryDraw(["ExternalConnected": false, "Voltage": 12000, "Amperage": -500, "MaxCapacity": 5000])! == (6.0, 60.0)) // Intel
    precondition(batteryDraw(["ExternalConnected": true, "Voltage": 12000, "InstantAmperage": 2000, "AppleRawMaxCapacity": 8000]) == nil)
    precondition(pmsetCmds.contains("-b lowpowermode 1") && pmsetCmds.contains("-c powermode 2"))
    precondition(Set(glyphs.keys) == ["active", "disabled", "setup"])
    print("glyphs from SVG: \(glyphSVG.values.allSatisfy { NSImage(data: Data("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 18 18'>\($0)</svg>".utf8)) != nil })")
    precondition(supportLinks.allSatisfy { URL(string: $0.1)?.host != nil })
    print("lid: \(hasLid ? "yes" : "no"), power key: \(powerModeSettings().map { "\($0.key) \($0.values)" } ?? "none")")
    print("draw now: \(batteryDraw().map { String(format: "%.1f W of %.0f Wh", $0.watts, $0.capacityWh) } ?? "on AC")")
    print("ok, battery now: \(batteryPercent().map { "\($0)%" } ?? "on AC"), thermal: \(ProcessInfo.processInfo.thermalState.rawValue)")
    exit(0)
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
