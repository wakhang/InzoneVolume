import AppKit
import CoreAudio
import ServiceManagement
import ApplicationServices

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let gain = GainState()
    private var routes: [String: AudioRoute] = [:]
    private var devices: [OutputDevice] = []
    private var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var refreshWork: DispatchWorkItem?
    private var errorMessage: String?
    private let slider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let muteItem = NSMenuItem(title: "음소거", action: #selector(toggleMute), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "로그인 시 실행", action: #selector(toggleLogin), keyEquivalent: "")
    private var keyMonitor: VolumeKeys?
    private let hud = VolumeHUD()
    private var volume: Double = 1
    private var muted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        volume = defaults.object(forKey: "volume") == nil ? 1 : defaults.double(forKey: "volume")
        volume = min(1, max(0, volume)); muted = defaults.bool(forKey: "muted")
        updateGain()
        let menu = NSMenu(); menu.delegate = self
        stateItem.isEnabled = false; menu.addItem(stateItem)
        let sliderItem = NSMenuItem(); slider.frame = NSRect(x: 12, y: 3, width: 210, height: 24)
        slider.target = self; slider.action = #selector(sliderChanged); slider.doubleValue = volume
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 234, height: 30)); container.addSubview(slider); sliderItem.view = container
        menu.addItem(sliderItem)
        muteItem.target = self; menu.addItem(muteItem)
        loginItem.target = self; menu.addItem(loginItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        statusItem.menu = menu
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            var address = AudioDevices.address(selector)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.scheduleRefresh() }
            if AudioObjectAddPropertyListenerBlock(AudioDevices.system, &address, DispatchQueue.main, block) == noErr { listeners.append((address, block)) }
        }
        keyMonitor = VolumeKeys { [weak self] code, fine in self?.handleKey(code, fine: fine) ?? false }
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        keyMonitor?.start()
        refresh()
    }
    func applicationWillTerminate(_ notification: Notification) {
        refreshWork?.cancel(); keyMonitor?.stop()
        for (var address, block) in listeners { AudioObjectRemovePropertyListenerBlock(AudioDevices.system, &address, DispatchQueue.main, block) }
        routes.values.forEach { $0.close() }; routes.removeAll()
    }
    func menuWillOpen(_ menu: NSMenu) {
        keyMonitor?.start()
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        updateUI()
    }
    private func scheduleRefresh() {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        refreshWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
    private func refresh() {
        devices = AudioDevices.outputs()
        let current = Set(devices.map(\.uid))
        for uid in Array(routes.keys) where !current.contains(uid) || !devices.contains(where: { $0.uid == uid && $0.id == routes[uid]?.device.id }) {
            routes.removeValue(forKey: uid)?.close()
        }
        errorMessage = nil
        if let own = AudioDevices.ownProcessObject() {
            for device in devices where routes[device.uid] == nil {
                do { routes[device.uid] = try AudioRoute(device: device, gain: gain, ownProcess: own) }
                catch { errorMessage = "\(device.name): \(error.localizedDescription)"; NSLog("%@", errorMessage!) }
            }
        } else if !devices.isEmpty { errorMessage = "현재 오디오 프로세스를 찾지 못했습니다" }
        updateUI()
    }
    private func updateGain() {
        gain.set(muted ? 0 : Float(volume * volume))
        UserDefaults.standard.set(volume, forKey: "volume"); UserDefaults.standard.set(muted, forKey: "muted")
    }
    private func updateUI() {
        slider.doubleValue = volume; muteItem.state = muted ? .on : .off
        let level = muted || volume == 0 ? "speaker.slash.fill" : volume < 0.34 ? "speaker.wave.1.fill" : volume < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        statusItem.button?.image = NSImage(systemSymbolName: level, accessibilityDescription: "INZONE 볼륨")
        var messages: [String] = []
        if routes.isEmpty { messages.append("INZONE 출력 장치 없음") }
        else { messages.append("활성: " + routes.values.map { $0.device.name }.sorted().joined(separator: ", ")) }
        if let errorMessage { messages.append(errorMessage) }
        if !AXIsProcessTrusted() { messages.append("손쉬운 사용 권한이 필요합니다") }
        stateItem.title = messages.joined(separator: " · ")
    }
    @objc private func sliderChanged() { volume = slider.doubleValue; updateGain(); updateUI() }
    @objc private func toggleMute() { muted.toggle(); updateGain(); updateUI() }
    @objc private func toggleLogin() {
        do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } }
        catch { errorMessage = "로그인 항목: \(error.localizedDescription)"; updateUI() }
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
    private func handleKey(_ code: Int, fine: Bool) -> Bool {
        guard devices.contains(where: { $0.id == AudioDevices.defaultOutput() && routes[$0.uid] != nil }) else { return false }
        if code == 7 { muted.toggle() }
        else { volume = min(1, max(0, volume + (code == 0 ? 1 : -1) / (fine ? 64.0 : 16.0))); muted = false }
        updateGain(); updateUI(); hud.show(volume: volume, muted: muted)
        return true
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
