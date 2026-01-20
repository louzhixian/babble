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

            Section("润色") {
                ForEach(RefineOption.allCases, id: \.self) { option in
                    Toggle(option.rawValue, isOn: bindingForOption(option))
                }
            }

            ForEach(RefineOption.allCases, id: \.self) { option in
                Section {
                    TextEditor(text: bindingForPrompt(option))
                        .frame(minHeight: 60)
                        .font(.body)
                } header: {
                    Text("\(option.rawValue) 提示词")
                } footer: {
                    Text("默认: \(option.prompt)")
                        .font(.caption)
                }
            }

            if !model.defaultRefineOptions.isEmpty {
                Section("完整提示词预览") {
                    Text(combinedPromptPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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

    private func bindingForOption(_ option: RefineOption) -> Binding<Bool> {
        Binding(
            get: { model.defaultRefineOptions.contains(option) },
            set: { isOn in
                if isOn {
                    if !model.defaultRefineOptions.contains(option) {
                        model.defaultRefineOptions.append(option)
                    }
                } else {
                    model.defaultRefineOptions.removeAll { $0 == option }
                }
            }
        )
    }

    private func bindingForPrompt(_ option: RefineOption) -> Binding<String> {
        Binding(
            get: { model.customPrompts[option] ?? "" },
            set: { newValue in
                var next = model.customPrompts
                if newValue.isEmpty {
                    next.removeValue(forKey: option)
                } else {
                    next[option] = newValue
                }
                model.customPrompts = next
            }
        )
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

    private var combinedPromptPreview: String {
        let orderedOptions: [RefineOption] = [.correct, .punctuate, .polish]
        let enabledOptions = Set(model.defaultRefineOptions)
        let prompts: [String] = orderedOptions.compactMap { option in
            guard enabledOptions.contains(option) else { return nil }
            return model.customPrompts[option] ?? option.prompt
        }
        return prompts.joined(separator: "\n")
    }
}
