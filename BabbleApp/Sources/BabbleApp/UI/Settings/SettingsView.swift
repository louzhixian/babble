import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var model: SettingsViewModel
    @State private var showResetPromptAlert = false
    @State private var isRecordingHotkey = false

    init(store: SettingsStore) {
        _model = StateObject(wrappedValue: SettingsViewModel(store: store))
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("快捷键")
                    Spacer()
                    HotkeyRecorderView(
                        hotkeyConfig: $model.hotkeyConfig,
                        isRecording: $isRecordingHotkey
                    )
                    .frame(width: 150, height: 28)
                }
            } header: {
                Text("快捷键")
            } footer: {
                Text("点击输入框，然后按下想要的快捷键组合（需要至少一个修饰键）")
            }

            Section("历史") {
                Stepper(value: $model.historyLimit, in: 10...1000, step: 10) {
                    HStack {
                        Text("保留条数")
                        Spacer()
                        Text("\(model.historyLimit)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle("启用润色", isOn: $model.refineEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("提示词")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("重置为默认") {
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
                Text("润色")
            }

            Section("识别") {
                Picker("默认语言", selection: $model.defaultLanguage) {
                    Text("自动检测").tag("")
                    Text("中文").tag("zh")
                    Text("英语").tag("en")
                    Text("日语").tag("ja")
                    Text("韩语").tag("ko")
                    Text("法语").tag("fr")
                    Text("德语").tag("de")
                    Text("西班牙语").tag("es")
                }
            }

            Section("粘贴") {
                Toggle("复制后清空剪贴板", isOn: $model.clearClipboardAfterCopy)
            }

            Section {
                Toggle("启用热区", isOn: $model.hotzoneEnabled)
                Picker("热区位置", selection: $model.hotzoneCorner) {
                    ForEach(HotzoneCorner.allCases, id: \.self) { corner in
                        Text(cornerLabel(corner)).tag(corner)
                    }
                }
                Slider(value: $model.hotzoneHoldSeconds, in: 0.2...2.0, step: 0.1) {
                    Text("触发停留秒数")
                }
                HStack {
                    Text("停留秒数")
                    Spacer()
                    Text(String(format: "%.1f", model.hotzoneHoldSeconds))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("热区触发")
            } footer: {
                Text("将鼠标移动到屏幕角落并停留指定时间即可触发录音")
            }

            Section {
                Toggle("启用 Force Touch", isOn: $model.forceTouchEnabled)
                Slider(value: $model.forceTouchHoldSeconds, in: 0.5...3.0, step: 0.1) {
                    Text("触发停留秒数")
                }
                HStack {
                    Text("停留秒数")
                    Spacer()
                    Text(String(format: "%.1f", model.forceTouchHoldSeconds))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Force Touch 触发")
            } footer: {
                Text("在触控板上用力按压并保持指定时间即可触发录音，松开后开始转写")
            }

        }
        .formStyle(.grouped)
        .padding()
        .alert("重置提示词？", isPresented: $showResetPromptAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                model.resetRefinePrompt()
            }
        } message: {
            Text("确定要将提示词重置为默认值吗？")
        }
    }

    private func cornerLabel(_ corner: HotzoneCorner) -> String {
        switch corner {
        case .topLeft:
            return "左上"
        case .topRight:
            return "右上"
        case .bottomLeft:
            return "左下"
        case .bottomRight:
            return "右下"
        }
    }
}

