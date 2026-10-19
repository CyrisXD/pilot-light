import Cocoa
import IOKit
import IOKit.ps
import ServiceManagement

// Pilot Light keeps a MacBook awake with the lid closed while you're logged in, switches it to
// Low Power Mode and turns the display off, then puts everything back when the lid opens.
// Logging out, switching users or quitting restores normal lid-close sleep, and so does locking the
// screen when "Keep awake when screen locked" is off.

// Rename this file whenever pmsetCmds changes, so existing installs are asked to reinstall the helper.
let sudoersPath = "/etc/sudoers.d/pilotlight"
// Background check that turns lid-close sleep back on if Pilot Light isn't running (after a crash
// or force quit), so the Mac never stays awake unattended. Bundled in Contents/Library/LaunchAgents.
let watchdog = SMAppService.agent(plistName: "nz.sudolabs.pilotlight.watchdog.plist")

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

// True when an external display is in use. With the lid closed that's a normal desk setup
// (clamshell mode), so Pilot Light leaves the displays and power mode alone.
func externalDisplayActive() -> Bool {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16), count: UInt32 = 0
    guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return false }
    return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
}

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

// Safety cutoffs while the lid is closed. The battery limit is set from the menu (0 = off).
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

// Update check: compares the latest GitHub release tag ("v1.2.0") with this build's version.
let releasesAPI = URL(string: "https://api.github.com/repos/CyrisXD/pilot-light/releases/latest")!
let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

func isNewer(_ tag: String, than current: String) -> Bool {
    let parts = { (v: String) in v.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 } }
    let a = parts(tag), b = parts(current)
    for i in 0..<max(a.count, b.count) where (i < a.count ? a[i] : 0) != (i < b.count ? b[i] : 0) {
        return (i < a.count ? a[i] : 0) > (i < b.count ? b[i] : 0)
    }
    return false
}

func statLine(_ label: String, sum: Double, n: Int, capacityWh: Double) -> String {
    guard n > 0 else { return "\(label): measuring on battery…" }
    let w = sum / Double(n)
    let hours = capacityWh > 0 ? String(format: " · ~%.0f h battery", capacityWh / w) : ""
    return String(format: "%@: %.1f W%@", label, w, hours)
}

// Menu bar template glyphs on an 18 pt grid: solid flame = on, outline = off,
// outline with a dot = helper not installed. macOS tints templates for light and dark menu bars.
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
    let removeItem = NSMenuItem(title: "Remove helper…", action: #selector(removeHelper), keyEquivalent: "")
    let lowPowerItem = NSMenuItem(title: "Low Power Mode when lid closed", action: #selector(flipLowPower), keyEquivalent: "")
    let cutoffItem = NSMenuItem(title: "Sleep when battery below", action: nil, keyEquivalent: "")
    let lockedItem = NSMenuItem(title: "Keep awake when screen locked", action: #selector(flipLocked), keyEquivalent: "")
    let loginItem = NSMenuItem(title: "Launch at login", action: #selector(flipLogin), keyEquivalent: "")
    let updatesItem = NSMenuItem(title: "Check for updates daily", action: #selector(flipUpdates), keyEquivalent: "")
    let updateAvailable = NSMenuItem(title: "", action: #selector(openUpdate), keyEquivalent: "")
    let updateSeparator = NSMenuItem.separator()
    var updateURL: URL?
    var checkUpdates: Bool { UserDefaults.standard.object(forKey: "checkUpdates") as? Bool ?? true }
    var lowPower: Bool { UserDefaults.standard.object(forKey: "lowPower") as? Bool ?? true }
    var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true
    var sessionActive = true
    var awakeWhenLocked: Bool { UserDefaults.standard.object(forKey: "awakeWhenLocked") as? Bool ?? true }
    var screenLocked = false
    var wasClosed = false
    var bailed = false // slept for safety; stays asleep until lid opens
    var deskMode = false // lid closed with an external display in use
    let openStat = NSMenuItem(), closedStat = NSMenuItem()
    let resetStats = NSMenuItem(title: "Reset power averages", action: #selector(reset), keyEquivalent: "")
    var lastChange = Date(), lastSample = Date.distantPast
    var capacityWh = 0.0

    var armed: Bool { enabled && sessionActive && hasLid && !(screenLocked && !awakeWhenLocked) }
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
        updateAvailable.isHidden = true
        updateSeparator.isHidden = true
        updateAvailable.target = self
        menu.addItem(updateAvailable)
        menu.addItem(updateSeparator)
        [install, toggle, lowPowerItem, lockedItem, loginItem, updatesItem, cutoffItem].forEach { $0.target = self; menu.addItem($0) }
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
        removeItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        removeItem.target = self
        menu.addItem(removeItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "q"))
        item.menu = menu

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sessionActive = false; self?.apply()
        }
        ws.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sessionActive = true; self?.apply()
        }
        // With "Keep awake when screen locked" off, any lock (yours, or the automatic one after the display
        // turns off) ends the stay-awake.
        let dn = DistributedNotificationCenter.default()
        dn.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenLocked = true; self?.apply()
        }
        dn.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenLocked = false; self?.apply()
        }
        // Posted on logout/shutdown/restart.
        ws.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { _ in restore() }

        restorePowerMode() // in case a previous run quit or crashed with the lid closed
        if helperOK { try? watchdog.register() }
        // Polls the lid every 2 seconds. An IOKit interest notification would react faster, but polling is simpler and cheap.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in self?.checkForUpdate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.checkForUpdate() }
        apply()
    }

    func applicationWillTerminate(_ n: Notification) { restore() }

    func apply() {
        bailed = false
        // disablesleep has to be set before the lid closes (lid close sleeps instantly),
        // so while armed it also stops idle sleep with the lid open. Display sleep is unaffected.
        pmset(armed ? "-a disablesleep 1" : "-a disablesleep 0")
        if !armed { restorePowerMode() }
        // Turning sleep back on while the lid is already shut doesn't sleep the Mac by itself.
        if !armed && wasClosed && !deskMode { run("/usr/bin/pmset", ["sleepnow"]) }
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
        let desk = closed && externalDisplayActive()
        if closed != wasClosed || desk != deskMode {
            wasClosed = closed
            deskMode = desk
            lastChange = Date()
            if armed && closed && !desk {
                if lowPower { lowPowerOn() }
                run("/usr/bin/pmset", ["displaysleepnow"])
            } else if armed {
                // Lid opened, or an external display took over while closed: back to normal.
                restorePowerMode()
                apply() // also re-arms after a safety sleep
            }
            refreshUI()
        }
        // Safety cutoff: lid closed and too hot or battery low → let it sleep. Not in a desk setup,
        // where someone is using the Mac on an external display.
        if armed && closed && !desk && !bailed, let why = bailReason(ProcessInfo.processInfo.thermalState, batteryPercent()) {
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
        guard Date().timeIntervalSince(lastChange) > 60, !wasClosed || (armed && !bailed && !deskMode),
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
        removeItem.isHidden = !helperOK
        lowPowerItem.isHidden = powerKey == nil || !hasLid
        item.button?.image = glyphs[!helper ? "setup" : armed ? "active" : "disabled"]
        item.button?.setAccessibilityLabel(!helper ? "Pilot Light: setup needed" : armed ? "Pilot Light: on" : "Pilot Light: off")
        item.button?.toolTip = !armed ? "Lid close: sleep"
            : deskMode ? "Lid closed with an external display: normal desk use"
            : "Lid close: stay awake, low power, screen off"
        lowPowerItem.state = lowPower ? .on : .off
        lockedItem.state = awakeWhenLocked ? .on : .off
        lockedItem.isHidden = !hasLid
        cutoffItem.submenu?.items.forEach { $0.state = $0.tag == minBatteryPercent ? .on : .off }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        updatesItem.state = checkUpdates ? .on : .off
        refreshStats()
    }

    @objc func flipLowPower() {
        UserDefaults.standard.set(!lowPower, forKey: "lowPower")
        refreshUI()
    }

    @objc func flipLocked() {
        UserDefaults.standard.set(!awakeWhenLocked, forKey: "awakeWhenLocked")
        apply()
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

    // One anonymous request a day to GitHub's public API; nothing about the Mac is sent.
    func checkForUpdate() {
        guard checkUpdates else { return }
        var req = URLRequest(url: releasesAPI)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("PilotLight/\(appVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String, let page = (json["html_url"] as? String).flatMap(URL.init) else { return }
            DispatchQueue.main.async {
                let newer = isNewer(tag, than: appVersion)
                self.updateURL = page
                self.updateAvailable.title = "Download Pilot Light \(tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV")))"
                self.updateAvailable.isHidden = !newer
                self.updateSeparator.isHidden = !newer
            }
        }.resume()
    }

    @objc func openUpdate() { if let u = updateURL { NSWorkspace.shared.open(u) } }

    @objc func flipUpdates() {
        UserDefaults.standard.set(!checkUpdates, forKey: "checkUpdates")
        if checkUpdates { checkForUpdate() } else { updateAvailable.isHidden = true; updateSeparator.isHidden = true }
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
        let sh = "/usr/sbin/visudo -cf '\(tmp)' && /usr/bin/install -m 0440 -o root -g wheel '\(tmp)' \(sudoersPath)"
        NSAppleScript(source: "do shell script \"\(sh)\" with administrator privileges")?.executeAndReturnError(nil)
        helperOK = FileManager.default.fileExists(atPath: sudoersPath)
        if helperOK { try? watchdog.register() }
        apply()
    }

    @objc func removeHelper() {
        let alert = NSAlert()
        alert.messageText = "Remove the Pilot Light helper?"
        alert.informativeText = "Your Mac goes back to sleeping when the lid closes. You can install the helper again from this menu."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        restore() // while sudo still allows it
        let removed = NSAppleScript(source: "do shell script \"/bin/rm -f \(sudoersPath)\" with administrator privileges")?.executeAndReturnError(nil) != nil
        guard removed else { return }
        try? watchdog.unregister()
        helperOK = FileManager.default.fileExists(atPath: sudoersPath)
        refreshUI()
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
    precondition(isNewer("v1.0.1", than: "1.0.0") && isNewer("v1.10.0", than: "1.9.3") && isNewer("2", than: "1.9"))
    precondition(!isNewer("v1.0.0", than: "1.0.0") && !isNewer("v0.9", than: "1.0.0") && !isNewer("1.0", than: "1.0.0"))
    precondition(supportLinks.allSatisfy { URL(string: $0.1)?.host != nil })
    print("Self-test passed.")
    print("This Mac: lid \(hasLid ? "yes" : "no"), external display \(externalDisplayActive() ? "yes" : "no"), power setting \(powerModeSettings()?.key ?? "none"), " +
          "battery \(batteryPercent().map { "\($0)%" } ?? "on AC"), draw \(batteryDraw().map { String(format: "%.1f W", $0.watts) } ?? "n/a on AC")")
    exit(0)
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
