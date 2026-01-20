import SwiftUI

struct SettingsView: View {
    @StateObject private var model: SettingsViewModel

    init(store: SettingsStore) {
        _model = StateObject(wrappedValue: SettingsViewModel(store: store))
    }

    var body: some View {
        Form {
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
                TextEditor(text: $model.refinePrompt)
                    .frame(minHeight: 80)
                    .font(.body)
            } header: {
                Text("润色")
            } footer: {
                Text("默认提示词: \(RefineService.defaultPrompt)")
                    .font(.caption)
            }

            Section("识别") {
                TextField("默认语言", text: $model.defaultLanguage)
                TextField("Whisper 端口", value: $model.whisperPort, format: .number)
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
