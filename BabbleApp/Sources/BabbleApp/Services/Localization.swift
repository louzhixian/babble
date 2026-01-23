// BabbleApp/Sources/BabbleApp/Services/Localization.swift

import Foundation

/// Supported languages
enum AppLanguage: String, CaseIterable, Sendable {
    case system = "system"
    case english = "en"
    case chinese = "zh"

    /// Display name for picker (uses both languages for clarity)
    var displayName: String {
        switch self {
        case .system: return "System / 跟随系统"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

/// Localization namespace - access via L10n.strings(for:) or L10n.system
enum L10n {
    /// Get strings for a specific language
    static func strings(for language: AppLanguage) -> LocalizedStrings {
        switch language {
        case .system:
            return systemStrings
        case .english:
            return EnglishStrings()
        case .chinese:
            return ChineseStrings()
        }
    }

    /// Get strings based on system language (for views without settings access)
    static var system: LocalizedStrings {
        systemStrings
    }

    private static var systemStrings: LocalizedStrings {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("zh") {
            return ChineseStrings()
        } else {
            return EnglishStrings()
        }
    }
}

/// Protocol for localized strings
protocol LocalizedStrings {
    // MARK: - Common
    var appName: String { get }
    var cancel: String { get }
    var confirm: String { get }
    var reset: String { get }
    var retry: String { get }
    var continueButton: String { get }
    var ready: String { get }

    // MARK: - Sidebar
    var settings: String { get }
    var history: String { get }

    // MARK: - Menu
    var mainWindow: String { get }
    var panelPosition: String { get }
    var quitApp: String { get }

    // MARK: - Panel Position
    var positionTop: String { get }
    var positionBottom: String { get }
    var positionLeft: String { get }
    var positionRight: String { get }
    var positionCenter: String { get }

    // MARK: - Settings
    var hotkey: String { get }
    var hotkeyHint: String { get }
    var historySection: String { get }
    var historyLimit: String { get }
    var refineSection: String { get }
    var refineEnabled: String { get }
    var refinePrompt: String { get }
    var resetToDefault: String { get }
    var resetPromptTitle: String { get }
    var resetPromptMessage: String { get }
    var recognitionSection: String { get }
    var defaultLanguage: String { get }
    var languageAuto: String { get }
    var languageChinese: String { get }
    var languageEnglish: String { get }
    var languageJapanese: String { get }
    var languageKorean: String { get }
    var languageFrench: String { get }
    var languageGerman: String { get }
    var languageSpanish: String { get }
    var pasteSection: String { get }
    var clearClipboardAfterCopy: String { get }
    var hotzoneSection: String { get }
    var hotzoneEnabled: String { get }
    var hotzoneCorner: String { get }
    var hotzoneHoldSeconds: String { get }
    var hotzoneHint: String { get }
    var cornerTopLeft: String { get }
    var cornerTopRight: String { get }
    var cornerBottomLeft: String { get }
    var cornerBottomRight: String { get }
    var forceTouchSection: String { get }
    var forceTouchEnabled: String { get }
    var forceTouchHoldSeconds: String { get }
    var forceTouchHint: String { get }
    var appLanguageSection: String { get }
    var appLanguage: String { get }
    var languageSystem: String { get }

    // MARK: - Download View
    var settingUpBabble: String { get }
    var checkingForUpdates: String { get }
    var downloadingSpeechEngine: String { get }
    var verifyingDownload: String { get }
    var downloadFailed: String { get }
    var manualDownload: String { get }
    var checkAgain: String { get }
    var manualDownloadHint: String { get }
    var downloadComplete: String { get }
    var permissionsNeeded: String { get }
    var microphonePermission: String { get }
    var accessibilityPermission: String { get }

    // MARK: - Setup Complete View
    var permissionsGranted: String { get }
    var permissionsReadyMessage: String { get }
    var continueToStart: String { get }
    var startingSpeechService: String { get }
    var initializingService: String { get }
    var loadingSpeechModel: String { get }
    var downloadingModel: String { get }
    var downloadingModelHint: String { get }
    var serviceError: String { get }
    var allSet: String { get }
    var babbleReady: String { get }
    var waysToStart: String { get }
    var pressHotkey: String { get }
    var forceTouchTrackpad: String { get }
    var moveToHotCorner: String { get }
    var enableInSettings: String { get }
    var startUsingBabble: String { get }

    // MARK: - Floating Panel
    var recording: String { get }
    var processing: String { get }
    var pasteManually: String { get }
    var somethingWentWrong: String { get }

    // MARK: - History
    var rawText: String { get }
    var refinedText: String { get }
    var edit: String { get }
    var copy: String { get }

    // MARK: - Permissions
    var permissionRequired: String { get }
    var permissionMessage: String { get }
    var openSystemPreferences: String { get }
    var later: String { get }
}

// MARK: - English Strings

struct EnglishStrings: LocalizedStrings {
    // Common
    let appName = "Babble"
    let cancel = "Cancel"
    let confirm = "Confirm"
    let reset = "Reset"
    let retry = "Retry"
    let continueButton = "Continue"
    let ready = "Ready"

    // Sidebar
    let settings = "Settings"
    let history = "History"

    // Menu
    let mainWindow = "Main Window"
    let panelPosition = "Panel Position"
    let quitApp = "Quit Babble"

    // Panel Position
    let positionTop = "Top"
    let positionBottom = "Bottom"
    let positionLeft = "Left"
    let positionRight = "Right"
    let positionCenter = "Center"

    // Settings
    let hotkey = "Hotkey"
    let hotkeyHint = "Click the input field, then press your desired key combination (requires at least one modifier key)"
    let historySection = "History"
    let historyLimit = "Keep entries"
    let refineSection = "Refinement"
    let refineEnabled = "Enable refinement"
    let refinePrompt = "Prompt"
    let resetToDefault = "Reset to default"
    let resetPromptTitle = "Reset prompt?"
    let resetPromptMessage = "Are you sure you want to reset the prompt to default?"
    let recognitionSection = "Recognition"
    let defaultLanguage = "Default language"
    let languageAuto = "Auto detect"
    let languageChinese = "Chinese"
    let languageEnglish = "English"
    let languageJapanese = "Japanese"
    let languageKorean = "Korean"
    let languageFrench = "French"
    let languageGerman = "German"
    let languageSpanish = "Spanish"
    let pasteSection = "Paste"
    let clearClipboardAfterCopy = "Clear clipboard after paste"
    let hotzoneSection = "Hot Corner Trigger"
    let hotzoneEnabled = "Enable hot corner"
    let hotzoneCorner = "Corner position"
    let hotzoneHoldSeconds = "Hold duration"
    let hotzoneHint = "Move cursor to screen corner and hold for specified duration to start recording"
    let cornerTopLeft = "Top Left"
    let cornerTopRight = "Top Right"
    let cornerBottomLeft = "Bottom Left"
    let cornerBottomRight = "Bottom Right"
    let forceTouchSection = "Force Touch Trigger"
    let forceTouchEnabled = "Enable Force Touch"
    let forceTouchHoldSeconds = "Hold duration"
    let forceTouchHint = "Press firmly on trackpad and hold for specified duration to start recording, release to transcribe"
    let appLanguageSection = "Language"
    let appLanguage = "App language"
    let languageSystem = "System"

    // Download View
    let settingUpBabble = "Setting Up Babble"
    let checkingForUpdates = "Checking for updates..."
    let downloadingSpeechEngine = "Downloading speech engine..."
    let verifyingDownload = "Verifying download..."
    let downloadFailed = "Download Failed"
    let manualDownload = "Manual Download"
    let checkAgain = "Check Again"
    let manualDownloadHint = "Download both whisper-service and whisper-service.sha256,\nthen place them in ~/Library/Application Support/Babble/\nClick \"Check Again\" after placing the files."
    let downloadComplete = "Download Complete!"
    let permissionsNeeded = "Next, Babble needs permissions to work properly:"
    let microphonePermission = "Microphone — for voice recording"
    let accessibilityPermission = "Accessibility — for pasting text"

    // Setup Complete View
    let permissionsGranted = "Permissions Granted!"
    let permissionsReadyMessage = "Microphone and Accessibility permissions are ready."
    let continueToStart = "Click Continue to start the speech recognition service."
    let startingSpeechService = "Starting Speech Service..."
    let initializingService = "Initializing speech recognition service..."
    let loadingSpeechModel = "Loading Speech Model..."
    let downloadingModel = "Downloading and loading speech model..."
    let downloadingModelHint = "This may take a few minutes on first launch (~1.5GB)"
    let serviceError = "Service Error"
    let allSet = "All Set!"
    let babbleReady = "Babble is ready to use!"
    let waysToStart = "Ways to start voice input:"
    let pressHotkey = "Press Option + Space"
    let forceTouchTrackpad = "Force Touch the trackpad"
    let moveToHotCorner = "Move cursor to hot corner"
    let enableInSettings = "Enable in Settings"
    let startUsingBabble = "Start Using Babble"

    // Floating Panel
    let recording = "Recording..."
    let processing = "Processing..."
    let pasteManually = "You can paste at the target location"
    let somethingWentWrong = "Something went wrong"

    // History
    let rawText = "Raw"
    let refinedText = "Refined"
    let edit = "Edit"
    let copy = "Copy"

    // Permissions
    let permissionRequired = "Permission Required"
    let permissionMessage = "Babble needs %@ permission to function. Please grant it in System Preferences."
    let openSystemPreferences = "Open System Preferences"
    let later = "Later"
}

// MARK: - Chinese Strings

struct ChineseStrings: LocalizedStrings {
    // Common
    let appName = "Babble"
    let cancel = "取消"
    let confirm = "确定"
    let reset = "重置"
    let retry = "重试"
    let continueButton = "继续"
    let ready = "就绪"

    // Sidebar
    let settings = "设置"
    let history = "历史"

    // Menu
    let mainWindow = "主窗口"
    let panelPosition = "面板位置"
    let quitApp = "退出 Babble"

    // Panel Position
    let positionTop = "上"
    let positionBottom = "下"
    let positionLeft = "左"
    let positionRight = "右"
    let positionCenter = "中"

    // Settings
    let hotkey = "快捷键"
    let hotkeyHint = "点击输入框，然后按下想要的快捷键组合（需要至少一个修饰键）"
    let historySection = "历史"
    let historyLimit = "保留条数"
    let refineSection = "润色"
    let refineEnabled = "启用润色"
    let refinePrompt = "提示词"
    let resetToDefault = "重置为默认"
    let resetPromptTitle = "重置提示词？"
    let resetPromptMessage = "确定要将提示词重置为默认值吗？"
    let recognitionSection = "识别"
    let defaultLanguage = "默认语言"
    let languageAuto = "自动检测"
    let languageChinese = "中文"
    let languageEnglish = "英语"
    let languageJapanese = "日语"
    let languageKorean = "韩语"
    let languageFrench = "法语"
    let languageGerman = "德语"
    let languageSpanish = "西班牙语"
    let pasteSection = "粘贴"
    let clearClipboardAfterCopy = "复制后清空剪贴板"
    let hotzoneSection = "热区触发"
    let hotzoneEnabled = "启用热区"
    let hotzoneCorner = "热区位置"
    let hotzoneHoldSeconds = "触发停留秒数"
    let hotzoneHint = "将鼠标移动到屏幕角落并停留指定时间即可触发录音"
    let cornerTopLeft = "左上"
    let cornerTopRight = "右上"
    let cornerBottomLeft = "左下"
    let cornerBottomRight = "右下"
    let forceTouchSection = "Force Touch 触发"
    let forceTouchEnabled = "启用 Force Touch"
    let forceTouchHoldSeconds = "触发停留秒数"
    let forceTouchHint = "在触控板上用力按压并保持指定时间即可触发录音，松开后开始转写"
    let appLanguageSection = "语言"
    let appLanguage = "应用语言"
    let languageSystem = "跟随系统"

    // Download View
    let settingUpBabble = "正在设置 Babble"
    let checkingForUpdates = "正在检查更新..."
    let downloadingSpeechEngine = "正在下载语音引擎..."
    let verifyingDownload = "正在验证下载..."
    let downloadFailed = "下载失败"
    let manualDownload = "手动下载"
    let checkAgain = "重新检查"
    let manualDownloadHint = "下载 whisper-service 和 whisper-service.sha256，\n放入 ~/Library/Application Support/Babble/\n放置完成后点击「重新检查」"
    let downloadComplete = "下载完成！"
    let permissionsNeeded = "接下来，Babble 需要以下权限才能正常工作："
    let microphonePermission = "麦克风 — 用于录音"
    let accessibilityPermission = "辅助功能 — 用于粘贴文本"

    // Setup Complete View
    let permissionsGranted = "权限已授予！"
    let permissionsReadyMessage = "麦克风和辅助功能权限已就绪。"
    let continueToStart = "点击继续以启动语音识别服务。"
    let startingSpeechService = "正在启动语音服务..."
    let initializingService = "正在初始化语音识别服务..."
    let loadingSpeechModel = "正在加载语音模型..."
    let downloadingModel = "正在下载并加载语音模型..."
    let downloadingModelHint = "首次启动可能需要几分钟（约 1.5GB）"
    let serviceError = "服务错误"
    let allSet = "准备就绪！"
    let babbleReady = "Babble 已准备好使用！"
    let waysToStart = "启动语音输入的方式："
    let pressHotkey = "按下 Option + Space"
    let forceTouchTrackpad = "用力按压触控板"
    let moveToHotCorner = "将光标移到屏幕角落"
    let enableInSettings = "需在设置中开启"
    let startUsingBabble = "开始使用 Babble"

    // Floating Panel
    let recording = "录音中..."
    let processing = "处理中..."
    let pasteManually = "你可以在目标位置粘贴"
    let somethingWentWrong = "出错了"

    // History
    let rawText = "原文"
    let refinedText = "润色"
    let edit = "编辑"
    let copy = "复制"

    // Permissions
    let permissionRequired = "需要权限"
    let permissionMessage = "Babble 需要%@权限才能正常工作，请在系统偏好设置中授予。"
    let openSystemPreferences = "打开系统偏好设置"
    let later = "稍后"
}
