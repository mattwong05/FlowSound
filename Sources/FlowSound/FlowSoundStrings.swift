import Foundation

enum FlowSoundLanguage: Sendable {
    case english
    case simplifiedChinese

    static var current: FlowSoundLanguage {
        let preference = FlowSoundLanguagePreference(
            rawValue: UserDefaults.standard.string(forKey: FlowSoundLanguagePreference.defaultsKey) ?? ""
        ) ?? .system
        if preference != .system {
            return preference.language
        }
        let languageCode = Locale.preferredLanguages.first?.lowercased() ?? ""
        return languageCode.hasPrefix("zh") ? .simplifiedChinese : .english
    }
}

enum FlowSoundLanguagePreference: String, Sendable, Equatable, CaseIterable {
    case system
    case english
    case simplifiedChinese

    static let defaultsKey = "languagePreference"

    var language: FlowSoundLanguage {
        switch self {
        case .system:
            let languageCode = Locale.preferredLanguages.first?.lowercased() ?? ""
            return languageCode.hasPrefix("zh") ? .simplifiedChinese : .english
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        }
    }

    var label: String {
        switch self {
        case .system:
            FlowSoundStrings.text(.languageSystem)
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }
}

enum FlowSoundStrings {
    enum Key {
        case aboutDetail
        case aboutTitle
        case activeDuration
        case activeDurationHelp
        case activeThreshold
        case activeThresholdHelp
        case activated
        case advanced
        case advancedHelp
        case advancedToggleHide
        case advancedToggleShow
        case allNonMusic
        case appStatusExcluded
        case appStatusWatched
        case appStatusDetected
        case appStatusSelectedMusic
        case audioMonitoring
        case audioMonitoringHelp
        case automationUnavailable(String)
        case deactivated
        case ducking(String)
        case excludedApps
        case excludedAppsHelp
        case fadeIn
        case fadeInHelp
        case fadeOut
        case fadeOutHelp
        case launchAtLogin
        case launchAtLoginDisabled
        case launchAtLoginEnabled
        case launchAtLoginNotFound
        case launchAtLoginRequiresApproval
        case launchAtLoginUnknown
        case language
        case languageHelp
        case languageSystem
        case monitoringTab
        case generalTab
        case toolsTab
        case menuActivate
        case menuDeactivate
        case menuAbout
        case menuCopyDiagnostics
        case menuPreferences
        case menuQuit
        case menuShowDiagnostics
        case menuSimulateActive
        case menuSimulateQuiet
        case musicPaused(String)
        case musicPlayer
        case musicPlayerHelp
        case openLoginItems
        case pausedByFlowSound(String)
        case preferencesTitle
        case quietDuration
        case quietDurationHelp
        case recentAudioSources
        case recentAudioSourcesEmpty
        case recentAudioSourcesHelp
        case refresh
        case resetDefaults
        case restoring(String)
        case save
        case status(String)
        case startupClose
        case startupCopyLogPath
        case startupDiagnostics(String)
        case startupMessage
        case startupTitle
        case timing
        case timingHelp
        case toolsDiagnostics
        case toolsDiagnosticsHelp
        case watchedAndExcludedHelp
        case watchedApps
        case watchedAppsHelp
        case version(String)
    }

    static func text(_ key: Key, language: FlowSoundLanguage = .current) -> String {
        switch language {
        case .english:
            english(key)
        case .simplifiedChinese:
            simplifiedChinese(key)
        }
    }

    private static func english(_ key: Key) -> String {
        switch key {
        case .aboutDetail:
            "A menu bar controller for fading music around other app audio."
        case .aboutTitle:
            "About FlowSound"
        case .activeDuration:
            "Active duration"
        case .activeDurationHelp:
            "Seconds before fading out. Default: 1.0"
        case .activeThreshold:
            "Active threshold"
        case .activeThresholdHelp:
            "RMS level needed to count audio as active. Default: 0.02"
        case .activated:
            "Activated"
        case .advanced:
            "Advanced"
        case .advancedHelp:
            "Bundle identifier filters for special cases."
        case .advancedToggleHide:
            "Hide bundle filters"
        case .advancedToggleShow:
            "Show bundle filters"
        case .allNonMusic:
            "All apps except music"
        case .appStatusExcluded:
            "Excluded"
        case .appStatusWatched:
            "Watched"
        case .appStatusDetected:
            "Detected"
        case .appStatusSelectedMusic:
            "Selected music app"
        case .audioMonitoring:
            "Audio monitoring"
        case .audioMonitoringHelp:
            "Default: watch every app except FlowSound, notifications, and the selected music app."
        case .automationUnavailable(let message):
            "Could not update launch at login: \(message)"
        case .deactivated:
            "Deactivated"
        case .ducking(let player):
            "Ducking \(player)"
        case .excludedApps:
            "Excluded apps"
        case .excludedAppsHelp:
            "Ignored in all-apps mode. One bundle identifier per line."
        case .fadeIn:
            "Fade in"
        case .fadeInHelp:
            "Seconds to restore volume. Default: 2.0"
        case .fadeOut:
            "Fade out"
        case .fadeOutHelp:
            "Seconds to fade before pause. Default: 2.0"
        case .launchAtLogin:
            "Launch FlowSound at login"
        case .launchAtLoginDisabled:
            "Launch at login is disabled."
        case .launchAtLoginEnabled:
            "Launch at login is enabled."
        case .launchAtLoginNotFound:
            "Launch at login is not registered for this build."
        case .launchAtLoginRequiresApproval:
            "Launch at login requires approval in System Settings."
        case .launchAtLoginUnknown:
            "Launch at login status is unknown."
        case .language:
            "Language"
        case .languageHelp:
            "Use System to follow macOS language. Changes apply after saving."
        case .languageSystem:
            "System"
        case .monitoringTab:
            "Monitoring"
        case .generalTab:
            "General"
        case .toolsTab:
            "Tools"
        case .menuActivate:
            "Activate FlowSound"
        case .menuDeactivate:
            "Deactivate FlowSound"
        case .menuAbout:
            "About FlowSound"
        case .menuCopyDiagnostics:
            "Copy Diagnostics Path"
        case .menuPreferences:
            "Preferences..."
        case .menuQuit:
            "Quit FlowSound"
        case .menuShowDiagnostics:
            "Show Diagnostics"
        case .menuSimulateActive:
            "Simulate Watched Audio"
        case .menuSimulateQuiet:
            "Simulate Quiet"
        case .musicPaused(let player):
            "\(player) paused"
        case .musicPlayer:
            "Music app"
        case .musicPlayerHelp:
            "FlowSound controls this app through local AppleScript."
        case .openLoginItems:
            "Open Login Items"
        case .pausedByFlowSound(let player):
            "\(player) paused"
        case .preferencesTitle:
            "FlowSound Preferences"
        case .quietDuration:
            "Quiet duration"
        case .quietDurationHelp:
            "Seconds of quiet before restoring. Default: 3.0"
        case .recentAudioSources:
            "Recently Detected Audio Sources"
        case .recentAudioSourcesEmpty:
            "No audio sources detected in the last 3 minutes. Start audio in another app, then refresh this panel."
        case .recentAudioSourcesHelp:
            "Shows Core Audio processes that recently reported output. Use these bundle identifiers in Watched apps or Excluded apps when needed."
        case .refresh:
            "Refresh"
        case .resetDefaults:
            "Reset Defaults"
        case .restoring(let player):
            "Restoring \(player)"
        case .save:
            "Save"
        case .status(let state):
            "Status: \(state)"
        case .startupClose:
            "Close"
        case .startupCopyLogPath:
            "Copy Log Path"
        case .startupDiagnostics(let path):
            "Diagnostics log:\n\(path)"
        case .startupMessage:
            "FlowSound runs from the macOS menu bar. If the menu bar item is hidden by macOS or a menu bar manager, this window confirms the app launched correctly."
        case .startupTitle:
            "FlowSound is running"
        case .timing:
            "Timing"
        case .timingHelp:
            "Tune how quickly FlowSound reacts and restores music."
        case .toolsDiagnostics:
            "Diagnostics"
        case .toolsDiagnosticsHelp:
            "Open the diagnostics window or copy the local log path."
        case .watchedAndExcludedHelp:
            "Use these raw bundle identifiers for browser helpers, notification daemons, and apps FlowSound cannot identify from a normal app picker."
        case .watchedApps:
            "Watched apps"
        case .watchedAppsHelp:
            "Used only in watched-app mode. One bundle identifier per line."
        case .version(let version):
            "Version \(version)"
        }
    }

    private static func simplifiedChinese(_ key: Key) -> String {
        switch key {
        case .aboutDetail:
            "在其他 App 播放声音时，自动淡出并暂停音乐的菜单栏工具。"
        case .aboutTitle:
            "关于 FlowSound"
        case .activeDuration:
            "触发时长"
        case .activeDurationHelp:
            "连续有声多久后淡出。默认：1.0 秒"
        case .activeThreshold:
            "声音阈值"
        case .activeThresholdHelp:
            "超过这个 RMS 音量才算有声。默认：0.02"
        case .activated:
            "已启用"
        case .advanced:
            "高级"
        case .advancedHelp:
            "特殊场景使用的 Bundle Identifier 过滤规则。"
        case .advancedToggleHide:
            "隐藏 Bundle 过滤器"
        case .advancedToggleShow:
            "显示 Bundle 过滤器"
        case .allNonMusic:
            "除音乐外的所有 App"
        case .appStatusExcluded:
            "已忽略"
        case .appStatusWatched:
            "已监听"
        case .appStatusDetected:
            "已检测到"
        case .appStatusSelectedMusic:
            "当前音乐 App"
        case .audioMonitoring:
            "音频监听"
        case .audioMonitoringHelp:
            "默认监听所有 App，但排除 FlowSound、通知和当前音乐 App。"
        case .automationUnavailable(let message):
            "无法更新开机自启：\(message)"
        case .deactivated:
            "已停用"
        case .ducking(let player):
            "正在淡出 \(player)"
        case .excludedApps:
            "忽略的 App"
        case .excludedAppsHelp:
            "在全局监听模式下忽略。每行一个 Bundle Identifier。"
        case .fadeIn:
            "淡入"
        case .fadeInHelp:
            "恢复音量所需时间。默认：2.0 秒"
        case .fadeOut:
            "淡出"
        case .fadeOutHelp:
            "暂停前淡出所需时间。默认：2.0 秒"
        case .launchAtLogin:
            "登录时启动 FlowSound"
        case .launchAtLoginDisabled:
            "开机自启已关闭。"
        case .launchAtLoginEnabled:
            "开机自启已开启。"
        case .launchAtLoginNotFound:
            "当前构建尚未注册开机自启。"
        case .launchAtLoginRequiresApproval:
            "开机自启需要在系统设置中批准。"
        case .launchAtLoginUnknown:
            "开机自启状态未知。"
        case .language:
            "语言"
        case .languageHelp:
            "选择“系统”时跟随 macOS 语言。保存后生效。"
        case .languageSystem:
            "系统"
        case .monitoringTab:
            "监听"
        case .generalTab:
            "通用"
        case .toolsTab:
            "工具"
        case .menuActivate:
            "启用 FlowSound"
        case .menuDeactivate:
            "停用 FlowSound"
        case .menuAbout:
            "关于 FlowSound"
        case .menuCopyDiagnostics:
            "复制诊断日志路径"
        case .menuPreferences:
            "偏好设置..."
        case .menuQuit:
            "退出 FlowSound"
        case .menuShowDiagnostics:
            "显示诊断窗口"
        case .menuSimulateActive:
            "模拟有声"
        case .menuSimulateQuiet:
            "模拟安静"
        case .musicPaused(let player):
            "\(player) 已暂停"
        case .musicPlayer:
            "音乐 App"
        case .musicPlayerHelp:
            "FlowSound 会通过本地 AppleScript 控制这个 App。"
        case .openLoginItems:
            "打开登录项"
        case .pausedByFlowSound(let player):
            "\(player) 已暂停"
        case .preferencesTitle:
            "FlowSound 偏好设置"
        case .quietDuration:
            "安静时长"
        case .quietDurationHelp:
            "安静多久后恢复播放。默认：3.0 秒"
        case .recentAudioSources:
            "最近检测到的发声源"
        case .recentAudioSourcesEmpty:
            "最近 3 分钟没有检测到发声源。请先在其他 App 播放声音，然后刷新这里。"
        case .recentAudioSourcesHelp:
            "显示最近向 Core Audio 报告输出的进程。需要时可把这些 Bundle Identifier 填入监听或忽略列表。"
        case .refresh:
            "刷新"
        case .resetDefaults:
            "恢复默认"
        case .restoring(let player):
            "正在恢复 \(player)"
        case .save:
            "保存"
        case .status(let state):
            "状态：\(state)"
        case .startupClose:
            "关闭"
        case .startupCopyLogPath:
            "复制日志路径"
        case .startupDiagnostics(let path):
            "诊断日志：\n\(path)"
        case .startupMessage:
            "FlowSound 在 macOS 菜单栏运行。如果菜单栏项目被 macOS 或菜单栏管理工具隐藏，这个窗口可以确认应用已经正常启动。"
        case .startupTitle:
            "FlowSound 正在运行"
        case .timing:
            "时间参数"
        case .timingHelp:
            "调整 FlowSound 的触发和恢复速度。"
        case .toolsDiagnostics:
            "诊断"
        case .toolsDiagnosticsHelp:
            "打开诊断窗口，或复制本地日志路径。"
        case .watchedAndExcludedHelp:
            "用于浏览器辅助进程、通知服务，以及 FlowSound 无法从普通 App 识别的特殊 Bundle Identifier。"
        case .watchedApps:
            "监听的 App"
        case .watchedAppsHelp:
            "仅在白名单模式下使用。每行一个 Bundle Identifier。"
        case .version(let version):
            "版本 \(version)"
        }
    }
}
