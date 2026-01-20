import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var model: SettingsViewModel
    @State private var showDiscardAlert = false

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

                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义提示词")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    PromptTextView(
                        text: Binding(
                            get: { model.refinePromptDraft },
                            set: { model.updateRefinePromptDraft($0) }
                        ),
                        placeholder: RefineService.defaultPrompt
                    )
                    .frame(minHeight: 100, maxHeight: 200)

                    if model.refinePromptHasChanges {
                        HStack {
                            Spacer()
                            Button("取消") {
                                showDiscardAlert = true
                            }
                            Button("保存") {
                                model.saveRefinePrompt()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } header: {
                Text("润色")
            } footer: {
                Text("留空则使用默认提示词")
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
        .alert("放弃更改？", isPresented: $showDiscardAlert) {
            Button("取消", role: .cancel) {}
            Button("放弃", role: .destructive) {
                model.discardRefinePromptChanges()
            }
        } message: {
            Text("您对提示词的修改尚未保存，确定要放弃吗？")
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

// NSTextView wrapper for proper keyboard input support
struct PromptTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true

        // Enable standard keyboard shortcuts
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView

        // Update text only if it differs (avoid cursor jumping)
        if textView.string != text {
            textView.string = text
        }

        // Show placeholder when empty
        if text.isEmpty {
            textView.textColor = .placeholderTextColor
            if textView.string.isEmpty {
                textView.string = placeholder
            }
        } else if textView.textColor == .placeholderTextColor {
            textView.textColor = .textColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PromptTextView
        private var isShowingPlaceholder: Bool

        init(_ parent: PromptTextView) {
            self.parent = parent
            self.isShowingPlaceholder = parent.text.isEmpty
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // Clear placeholder on focus if showing
            if isShowingPlaceholder {
                textView.string = ""
                textView.textColor = .textColor
                isShowingPlaceholder = false
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // Show placeholder if empty
            if textView.string.isEmpty {
                textView.string = parent.placeholder
                textView.textColor = .placeholderTextColor
                isShowingPlaceholder = true
            }
        }
    }
}
