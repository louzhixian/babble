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
                Toggle("记录目标应用", isOn: $model.recordTargetApp)
            }

            Section("润色") {
                Toggle("自动润色", isOn: $model.autoRefine)

                ForEach(RefineOption.allCases, id: \.self) { option in
                    Toggle(option.rawValue, isOn: bindingForOption(option))
                }
            }

            Section("自定义提示") {
                ForEach(RefineOption.allCases, id: \.self) { option in
                    TextField(option.rawValue, text: bindingForPrompt(option))
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("识别") {
                TextField("默认语言", text: $model.defaultLanguage)
                TextField("Whisper 端口", value: $model.whisperPort, format: .number)
            }

            Section("粘贴") {
                Toggle("复制后清空剪贴板", isOn: $model.clearClipboardAfterCopy)
                Toggle("复制后提示音", isOn: $model.playSoundOnCopy)
            }

            Section("热区触发") {
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
}
