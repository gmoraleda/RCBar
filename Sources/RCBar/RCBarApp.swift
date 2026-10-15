import AppKit
import SwiftUI

struct RCBarApp: App {
    @StateObject var model = Model()
    @AppStorage("muted") var muted = false

    init() { NSApplication.shared.setActivationPolicy(.accessory) }

    var body: some Scene {
        MenuBarExtra {
            ForEach(model.lines, id: \.self) { Text($0) }
            if let error = model.error {
                Divider()
                ForEach(error.components(separatedBy: "\n"), id: \.self) { Text($0) }
            }
            Divider()
            if let updated = model.updated { Text("Updated \(fmt(updated, "HH:mm", tz: .current))") }
            Button("Refresh") { Task { await model.refresh() } }.keyboardShortcut("r")
            Toggle("Sound on new purchase", isOn: Binding(get: { !muted }, set: { muted = !$0 }))
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            Button("Open RevenueCat dashboard") { NSWorkspace.shared.open(URL(string: "https://app.revenuecat.com")!) }
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Text(model.title)
        }
    }
}
