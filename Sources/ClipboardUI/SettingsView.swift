import AppKit
import ClipboardCore
import ClipboardPlatform
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: HistoryStore
    @ObservedObject var permission: AccessibilityPermission
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings, bridge: bridge)
                .tabItem { Label("General", systemImage: "gearshape") }
            ShortcutSettingsTab(settings: settings, bridge: bridge)
                .tabItem { Label("Shortcuts", systemImage: "command") }
            StorageSettingsTab(settings: settings, store: store, bridge: bridge)
                .tabItem { Label("Storage", systemImage: "internaldrive") }
            PermissionSettingsTab(permission: permission)
                .tabItem { Label("Permission", systemImage: "lock.shield") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 400)
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge

    private var historySize: Binding<Double> {
        Binding(
            get: { Double(settings.maxItems) },
            set: { settings.maxItems = Int($0.rounded()) }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Slider(value: historySize, in: 5...200, step: 1)
                        TextField(
                            "",
                            value: Binding(
                                get: { settings.maxItems },
                                set: { settings.maxItems = $0 }
                            ),
                            format: .number
                        )
                        .frame(width: 52)
                        .multilineTextAlignment(.trailing)
                        Stepper("", value: Binding(
                            get: { settings.maxItems },
                            set: { settings.maxItems = $0 }
                        ), in: AppSettings.maxItemsRange)
                        .labelsHidden()
                    }
                    Text("Older unpinned items are removed once the history is full.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("History size")
            }

            Section {
                Toggle("Paste automatically after choosing an item", isOn: $settings.autoPaste)
                Text("Requires Accessibility permission. When off, the item is only copied to the clipboard.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("Save copied images", isOn: $settings.captureImages)
            } header: {
                Text("Behaviour")
            }

            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppearancePreference.allCases, id: \.self) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                Text("System follows macOS Light/Dark. Light and Dark force the app chrome.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                .disabled(!bridge.isLoginItemAvailable)
                if !bridge.isLoginItemAvailable {
                    Text("Available once ClipboardX is running from an app bundle in /Applications.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if let error = bridge.loginItemError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                } else if !bridge.loginItemStatus.isEmpty {
                    Text(bridge.loginItemStatus)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Toggle("Show the menu bar icon", isOn: $settings.showsMenuBarIcon)
                if !settings.showsMenuBarIcon {
                    Text("With the icon hidden, use \(settings.openHistoryHotkey.displayString) to open the history.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        Form {
            Section {
                LabeledContent("Open clipboard history") {
                    ShortcutRecorder(
                        combo: $settings.openHistoryHotkey,
                        errorText: bridge.error(for: .openHistory)
                    )
                    .frame(width: 120, height: 24)
                }
                if let error = bridge.error(for: .openHistory) {
                    Text(error).font(.callout).foregroundStyle(.red)
                }

                Toggle("Enable “paste latest as plain text”", isOn: $settings.isPastePlainTextEnabled)
                LabeledContent("Paste latest as plain text") {
                    ShortcutRecorder(
                        combo: $settings.pastePlainTextHotkey,
                        errorText: bridge.error(for: .pastePlainText)
                    )
                    .frame(width: 120, height: 24)
                    .disabled(!settings.isPastePlainTextEnabled)
                    .opacity(settings.isPastePlainTextEnabled ? 1 : 0.4)
                }
                if let error = bridge.error(for: .pastePlainText) {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            } header: {
                Text("Global shortcuts")
            } footer: {
                Text("Click a shortcut, then press the keys you want. Escape cancels.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    shortcutRow("↑ ↓", "Move through the list")
                    shortcutRow("⏎", "Paste the selected item")
                    shortcutRow("⌥⏎", "Paste without formatting")
                    shortcutRow("⌘1 – ⌘9", "Paste that row directly")
                    shortcutRow("⌘P", "Pin or unpin the selected item")
                    shortcutRow("⌘⌫", "Delete the selected item")
                    shortcutRow("esc", "Clear the search, then close")
                }
            } header: {
                Text("Inside the popup")
            }

            Section {
                Button("Restore all defaults", action: bridge.resetSettings)
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(_ keys: String, _ description: String) -> some View {
        GridRow {
            Text(keys)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct StorageSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: HistoryStore
    @ObservedObject var bridge: SettingsBridge

    var body: some View {
        Form {
            Section {
                LabeledContent("Items stored", value: "\(store.items.count) of \(settings.maxItems)")
                LabeledContent("Pinned", value: "\(store.pinnedCount)")
                LabeledContent("Disk used", value: Formatting.bytes(bridge.storageBytes))
                Button("Show in Finder", action: bridge.revealStorage)
            } header: {
                Text("Stored data")
            }

            Section {
                Button("Clear unpinned history") { bridge.clearHistory(true) }
                Button("Clear everything, including pinned items", role: .destructive) {
                    bridge.clearHistory(false)
                }
            } header: {
                Text("Clear")
            }

            if let error = store.lastError {
                Section {
                    Text(error).font(.callout).foregroundStyle(.red)
                } header: {
                    Text("Last error")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: bridge.refreshStorage)
    }
}

private struct PermissionSettingsTab: View {
    @ObservedObject var permission: AccessibilityPermission

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: permission.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(permission.isTrusted ? .green : .orange)
                    Text(permission.isTrusted ? "Accessibility permission granted" : "Accessibility permission needed")
                        .font(.system(size: 13, weight: .medium))
                }
                Text(
                    permission.isTrusted
                        ? "ClipboardX can paste into other apps and place the popup at your text cursor."
                        : "Without it, ClipboardX still records your clipboard and copies the item you choose, but it cannot press ⌘V for you or find your text cursor."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                if !permission.isTrusted {
                    Text("If the toggle in System Settings already looks on, turn it off and on again for this build, then quit and reopen ClipboardX. macOS binds the grant to the app’s code signature.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Open System Settings", action: permission.openSystemSettings)
                        Button("Ask macOS again", action: permission.requestFromSystem)
                    }
                }
            } header: {
                Text("Accessibility")
            } footer: {
                Text("After granting the permission, quit and reopen ClipboardX so macOS applies it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: permission.refresh)
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("ClipboardX")
                .font(.system(size: 17, weight: .semibold))
            Text("Version \(AppInfo.version) (\(AppInfo.build))")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Clipboard history for macOS, in the spirit of Windows' Win+V.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
