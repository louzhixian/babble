import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var model: SettingsViewModel
    @State private var showResetPromptAlert = false
    @State private var isRecordingHotkey = false

    init(store: SettingsStore) {
        _model = StateObject(wrappedValue: SettingsViewModel(store: store))
    }

    private var l: LocalizedStrings {
        L10n.strings(for: model.appLanguage)
    }

    var body: some View {
        Form {
            Section {
                Picker(l.appLanguage, selection: $model.appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            } header: {
                Text(l.appLanguageSection)
            }

            Section {
                HStack {
                    Text(l.hotkey)
                    Spacer()
                    HotkeyRecorderView(
                        hotkeyConfig: $model.hotkeyConfig,
                        isRecording: $isRecordingHotkey
                    )
                    .frame(width: 150, height: 28)
                }
            } header: {
                Text(l.hotkey)
            } footer: {
                Text(l.hotkeyHint)
            }

            Section(l.historySection) {
                Stepper(value: $model.historyLimit, in: 10...1000, step: 10) {
                    HStack {
                        Text(l.historyLimit)
                        Spacer()
                        Text("\(model.historyLimit)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle(l.refineEnabled, isOn: $model.refineEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(l.refinePrompt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(l.resetToDefault) {
                            showResetPromptAlert = true
                        }
                        .font(.caption)
                        .disabled(model.refinePrompt == RefineService.defaultPrompt)
                    }

                    TextEditor(text: $model.refinePrompt)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .frame(minHeight: 100, maxHeight: 200)
                        .border(Color(nsColor: .separatorColor), width: 1)
                }
            } header: {
                Text(l.refineSection)
            }

            Section(l.recognitionSection) {
                Picker(l.defaultLanguage, selection: $model.defaultLanguage) {
                    Text(l.languageAuto).tag("")
                    Text(l.languageChinese).tag("zh")
                    Text(l.languageEnglish).tag("en")
                    Text(l.languageJapanese).tag("ja")
                    Text(l.languageKorean).tag("ko")
                    Text(l.languageFrench).tag("fr")
                    Text(l.languageGerman).tag("de")
                    Text(l.languageSpanish).tag("es")
                }
            }

            Section(l.pasteSection) {
                Toggle(l.clearClipboardAfterCopy, isOn: $model.clearClipboardAfterCopy)
            }

            Section {
                Toggle(l.hotzoneEnabled, isOn: $model.hotzoneEnabled)
                Picker(l.hotzoneCorner, selection: $model.hotzoneCorner) {
                    ForEach(HotzoneCorner.allCases, id: \.self) { corner in
                        Text(cornerLabel(corner)).tag(corner)
                    }
                }
                Slider(value: $model.hotzoneHoldSeconds, in: 0.2...2.0, step: 0.1) {
                    Text(l.hotzoneHoldSeconds)
                }
                HStack {
                    Text(l.hotzoneHoldSeconds)
                    Spacer()
                    Text(String(format: "%.1f", model.hotzoneHoldSeconds))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(l.hotzoneSection)
            } footer: {
                Text(l.hotzoneHint)
            }

            Section {
                Toggle(l.forceTouchEnabled, isOn: $model.forceTouchEnabled)
                Slider(value: $model.forceTouchHoldSeconds, in: 0.5...3.0, step: 0.1) {
                    Text(l.forceTouchHoldSeconds)
                }
                HStack {
                    Text(l.forceTouchHoldSeconds)
                    Spacer()
                    Text(String(format: "%.1f", model.forceTouchHoldSeconds))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(l.forceTouchSection)
            } footer: {
                Text(l.forceTouchHint)
            }

        }
        .formStyle(.grouped)
        .padding()
        .alert(l.resetPromptTitle, isPresented: $showResetPromptAlert) {
            Button(l.cancel, role: .cancel) {}
            Button(l.reset, role: .destructive) {
                model.resetRefinePrompt()
            }
        } message: {
            Text(l.resetPromptMessage)
        }
    }

    private func cornerLabel(_ corner: HotzoneCorner) -> String {
        switch corner {
        case .topLeft:
            return l.cornerTopLeft
        case .topRight:
            return l.cornerTopRight
        case .bottomLeft:
            return l.cornerBottomLeft
        case .bottomRight:
            return l.cornerBottomRight
        }
    }
}
