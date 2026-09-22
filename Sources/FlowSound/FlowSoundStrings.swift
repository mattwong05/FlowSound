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
        case draftSettingsHelp
        case cancel
        case chooseApplications
        case removeApplicationRule
        case fixedExclusionsHelp
        case addApplications
        case chooseWatchedApplications
        case chooseExcludedApplications
        case applicationMissingIdentifier
        case applicationRulesHelp
        case diagnosticsTitle
        case monitorStopped
        case monitorStarting
        case monitorRunning
        case monitorRecovering
        case notVerified
        case diagnosticMonitor
        case diagnosticAutomation
        case diagnosticAccessibility
        case diagnosticSignal
        case diagnosticSignalActive
        case diagnosticSignalQuiet
        case diagnosticMixHelp
        case permissionAllowed
        case permissionNotAllowed
        case permissionNotNeeded
        case openAudioCaptureSettings
        case openAutomationSettings
        case retryService
        case advancedDiagnostics
        case simulationHelp
        case restoreNotScheduled
        case restoreCountdown(Int)
        case automationSucceeded(String)
        case diagnosticFailure(String)
        case aboutDetail
        case aboutTitle
        case activeDuration
        case activeDurationHelp
        case activeThreshold
        case activeThresholdHelp
        case activated
        case starting
        case advanced
        case advancedHelp
        case advancedToggleHide
        case advancedToggleShow
        case allNonMusic
        case appStatusExcluded
        case appStatusWatched
        case appStatusDetected
        case appStatusSelectedMusic
        case addToExcludedApps
        case addToWatchedApps
        case adapterProfiles
        case adapterProfilesHelp
        case exportBundledAdapterProfile
        case exportAdapterProfileCompleted(String)
        case experimentalAdapters
        case importAdapterProfile
        case importAdapterProfileCompleted(Int, String)
        case importAdapterProfileEmpty(String)
        case neteaseAccessHelp
        case neteaseVolumeHelp
        case openAccessibilitySettings
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
        case .draftSettingsHelp:
            "Changes on all tabs, including app rules and Reset Defaults, apply after Save. Cancel discards them."
        case .cancel:
            "Cancel"
        case .removeApplicationRule:
            "Remove"
        case .fixedExclusionsHelp:
            "These are editable rules. The selected music app and FlowSound always stay excluded, even if removed from this list."
        case .chooseApplications:
            "Choose Applications"
        case .addApplications:
            "Add"
        case .chooseWatchedApplications:
            "Add Watched Apps…"
        case .chooseExcludedApplications:
            "Add Excluded Apps…"
        case .applicationMissingIdentifier:
            "An app has no valid bundle identifier. No apps were added; use the advanced bundle filters for helpers and system processes."
        case .applicationRulesHelp:
            "Choose installed apps by name and icon. Watched rules apply only in watched-app mode; exclusions take priority in both modes."
        case .diagnosticsTitle:
            "FlowSound Diagnostics"
        case .monitorStopped:
            "Stopped"
        case .monitorStarting:
            "Starting audio capture…"
        case .monitorRunning:
            "Audio tap running (permission is not independently verified)"
        case .monitorRecovering:
            "Recovering audio capture…"
        case .notVerified:
            "Not yet verified"
        case .diagnosticMonitor:
            "Audio capture"
        case .diagnosticAutomation:
            "Player automation"
        case .diagnosticAccessibility:
            "Accessibility"
        case .diagnosticSignal:
            "Detection signal"
        case .diagnosticSignalActive:
            "Active audio signal"
        case .diagnosticSignalQuiet:
            "Quiet signal"
        case .diagnosticMixHelp:
            "The tap measures mixed audio. Recent output processes help configure rules, but do not prove which app caused a pause."
        case .permissionAllowed:
            "Allowed"
        case .permissionNotAllowed:
            "Not allowed"
        case .permissionNotNeeded:
            "Not required for this player"
        case .openAudioCaptureSettings:
            "Audio Capture Settings"
        case .openAutomationSettings:
            "Automation Settings"
        case .retryService:
            "Retry Monitoring"
        case .advancedDiagnostics:
            "Advanced Diagnostics"
        case .simulationHelp:
            "Simulation controls the selected music app. It does not verify audio capture or permissions."
        case .restoreNotScheduled:
            "No restore scheduled"
        case .restoreCountdown(let seconds):
            "Restoring in \(seconds) seconds"
        case .automationSucceeded(let time):
            "Last successful command: \(time)"
        case .diagnosticFailure(let message):
            "Failed: \(message)"

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
        case .starting:
            "Starting…"
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
        case .addToExcludedApps:
            "Exclude"
        case .addToWatchedApps:
            "Watch"
        case .adapterProfiles:
            "Adapter Profiles"
        case .adapterProfilesHelp:
            "Import or export transparent adapter profiles. Imported profiles are metadata only; FlowSound does not run arbitrary downloaded scripts."
        case .exportBundledAdapterProfile:
            "Export Netease Profile"
        case .exportAdapterProfileCompleted(let path):
            "Exported adapter profile:\n\(path)"
        case .experimentalAdapters:
            "Experimental adapters"
        case .importAdapterProfile:
            "Import Local Profiles"
        case .importAdapterProfileCompleted(let count, let path):
            "Imported \(count) adapter profile(s) from:\n\(path)"
        case .importAdapterProfileEmpty(let path):
            "No local adapter profile JSON files were found. Put .json profiles in this folder, then click Import Local Profiles again:\n\(path)"
        case .neteaseAccessHelp:
            "Netease Cloud Music needs Accessibility permission because FlowSound controls its Controls menu. Open System Settings > Privacy & Security > Accessibility and allow FlowSound. After updating FlowSound, remove and re-add FlowSound if control still fails."
        case .neteaseVolumeHelp:
            "Netease volume restore is approximate. The app exposes relative menu steps, usually about 5%, not an exact readable volume."
        case .openAccessibilitySettings:
            "Open Accessibility Settings"
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
            "Exclusions take priority in both modes. One bundle identifier or known system audio process per line."
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
            "Settings…"
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
            "Official adapters use native AppleScript. Experimental adapters may use menu commands and extra permissions."
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
            "Recent output processes are clues, not exact attribution of mixed audio. Watch/Exclude edits the draft; click Save to apply."
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
            "Use these raw identifiers for browser helpers, system audio services, notification daemons, and apps FlowSound cannot identify from a normal app picker."
        case .watchedApps:
            "Watched apps"
        case .watchedAppsHelp:
            "Used only in watched-app mode. One bundle identifier or known system audio process per line."
        case .version(let version):
            "Version \(version)"
        }
    }

    private static func simplifiedChinese(_ key: Key) -> String {
        switch key {
        case .draftSettingsHelp:
            "所有页面的修改（包括应用规则和恢复默认）均在保存后生效。取消会放弃修改。"
        case .cancel:
            "取消"
        case .removeApplicationRule:
            "移除"
        case .fixedExclusionsHelp:
            "这里显示可编辑规则。所选音乐应用和 FlowSound 始终被排除，即使从列表移除也不会被监听。"
        case .chooseApplications:
            "选择应用"
        case .addApplications:
            "添加"
        case .chooseWatchedApplications:
            "添加监听应用…"
        case .chooseExcludedApplications:
            "添加忽略应用…"
        case .applicationMissingIdentifier:
            "所选应用缺少有效的 Bundle Identifier，本次未添加。辅助进程和系统进程可使用高级 Bundle 过滤器。"
        case .applicationRulesHelp:
            "可按名称和图标选择已安装应用。监听列表仅在白名单模式下生效；忽略规则在两种模式下均优先。"
        case .diagnosticsTitle:
            "FlowSound 诊断"
        case .monitorStopped:
            "已停止"
        case .monitorStarting:
            "正在启动音频采集…"
        case .monitorRunning:
            "音频 Tap 正在运行（未单独验证权限）"
        case .monitorRecovering:
            "正在恢复音频采集…"
        case .notVerified:
            "尚未验证"
        case .diagnosticMonitor:
            "音频采集"
        case .diagnosticAutomation:
            "播放器自动化"
        case .diagnosticAccessibility:
            "辅助功能"
        case .diagnosticSignal:
            "检测信号"
        case .diagnosticSignalActive:
            "有声信号"
        case .diagnosticSignalQuiet:
            "安静信号"
        case .diagnosticMixHelp:
            "Tap 检测的是混合音频。最近输出进程可辅助配置规则，但不能证明具体哪个应用触发了暂停。"
        case .permissionAllowed:
            "已允许"
        case .permissionNotAllowed:
            "未允许"
        case .permissionNotNeeded:
            "当前播放器不需要"
        case .openAudioCaptureSettings:
            "音频采集设置"
        case .openAutomationSettings:
            "自动化设置"
        case .retryService:
            "重试监听"
        case .advancedDiagnostics:
            "高级诊断"
        case .simulationHelp:
            "模拟会控制所选音乐应用，不代表音频采集或权限已通过验证。"
        case .restoreNotScheduled:
            "尚未安排恢复"
        case .restoreCountdown(let seconds):
            "将在 \(seconds) 秒后恢复"
        case .automationSucceeded(let time):
            "最近命令成功：\(time)"
        case .diagnosticFailure(let message):
            "失败：\(message)"

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
        case .starting:
            "正在启动…"
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
        case .addToExcludedApps:
            "忽略"
        case .addToWatchedApps:
            "监听"
        case .adapterProfiles:
            "适配器配置"
        case .adapterProfilesHelp:
            "导入或导出透明的适配器配置。导入的配置目前只作为元数据保存；FlowSound 不会执行任意下载脚本。"
        case .exportBundledAdapterProfile:
            "导出网易云配置"
        case .exportAdapterProfileCompleted(let path):
            "已导出适配器配置：\n\(path)"
        case .experimentalAdapters:
            "实验适配器"
        case .importAdapterProfile:
            "导入本地配置"
        case .importAdapterProfileCompleted(let count, let path):
            "已从以下目录导入 \(count) 个适配器配置：\n\(path)"
        case .importAdapterProfileEmpty(let path):
            "未找到本地适配器 JSON 配置。请把 .json 配置文件放入此目录，然后再次点击“导入本地配置”：\n\(path)"
        case .neteaseAccessHelp:
            "网易云音乐需要无障碍权限，因为 FlowSound 需要点击它的“控制”菜单。请在“系统设置 > 隐私与安全性 > 辅助功能”中允许 FlowSound。更新 FlowSound 后如果仍然控制失败，请删除后重新添加 FlowSound。"
        case .neteaseVolumeHelp:
            "网易云音量恢复只能近似。它只暴露相对菜单步进，通常约 5%，不是可读取的精确音量。"
        case .openAccessibilitySettings:
            "打开无障碍设置"
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
            "忽略规则在两种模式下均优先。每行一个 Bundle Identifier 或已知系统音频进程。"
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
            "设置…"
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
            "官方适配器使用原生 AppleScript。实验适配器可能使用菜单命令并需要额外权限。"
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
            "最近输出进程仅作为线索，不能精确归因混合音频。监听/忽略按钮修改草稿，点击保存后生效。"
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
            "用于浏览器辅助进程、系统音频服务、通知服务，以及 FlowSound 无法从普通 App 识别的特殊标识。"
        case .watchedApps:
            "监听的 App"
        case .watchedAppsHelp:
            "仅在白名单模式下使用。每行一个 Bundle Identifier 或已知系统音频进程。"
        case .version(let version):
            "版本 \(version)"
        }
    }
}
