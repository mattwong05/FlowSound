const translations = {
  en: {
    navWhatsNew: "What’s new",
    navDemo: "Demo",
    navPrivacy: "Privacy",
    navPermissions: "Permissions",
    eyebrow: "Open-source macOS menu bar app",
    heroTitle: "Music that knows when to step aside.",
    heroText: "FlowSound fades and pauses Apple Music or Spotify when other apps play audio, then restores it when things become quiet again. Netease Cloud Music is available as an experimental adapter.",
    downloadPreview: "Try 0.18.0 preview",
    downloadStable: "Download stable 0.15.1",
    previewNote: "0.18.0 is a public preview, ad-hoc signed and not notarized. macOS may block it on first open. macOS 27 runtime testing is still pending.",
    heroNote: "Built for macOS 15+. Official Apple Music and Spotify support. Experimental Netease Cloud Music. Local-first, no analytics.",
    productHuntLabel: "Featured on",
    focusKicker: "Audio focus for your music app",
    focusTitle: "No overlap. No sudden silence.",
    withoutTitle: "Without FlowSound",
    withoutBadge: "manual",
    withTitle: "With FlowSound",
    withBadge: "automatic",
    appleMusicLabel: "Apple Music / Spotify / Netease",
    otherAudioLabel: "Video / other audio",
    withoutText: "Two soundtracks compete until you pause one by hand.",
    withText: "Music steps aside, then returns from the same paused position.",
    eventFade: "fade out",
    eventPause: "pause",
    eventResume: "resume",
    focusOutcome: "Avoid overlapping audio. Avoid sudden silence. Stay in flow.",
    releaseEyebrow: "New in 0.18.0 · Public preview",
    releaseTitle: "A clearer place for every setting.",
    releaseText: "Native controls, considered spacing, and a simpler way to decide which apps can interrupt your music.",
    screenshotLinkLabel: "View the settings screenshot at full size",
    screenshotAlt: "FlowSound application rules with separate Watched apps and Ignored apps columns",
    screenshotCaption: "Actual native interface with sample rules. Shown on macOS 26. Click to view full size.",
    rulesTitle: "Two lists. Clear choices.",
    rulesText: "Manage watched and ignored apps side by side, with app icons and aligned controls. Changes take effect only when you save.",
    timingTitle: "Get the timing right.",
    timingText: "Adjust fades and quiet time with familiar sliders, or enter an exact value in the dedicated Sound pane.",
    reliabilityTitle: "Know what’s happening.",
    reliabilityText: "See monitoring and permission status in Diagnostics. Recovery handles audio-device changes and sleep/wake, while playback controls respect observable manual changes.",
    releaseNotes: "Read the preview release notes →",
    demoEyebrow: "Demo",
    demoTitle: "Watch FlowSound react to other audio.",
    demoText: "The menu bar app listens for app audio activity, fades your selected music app out, pauses it, then restores the previous volume.",
    trustEyebrow: "Trust",
    trustTitle: "Simple, local, auditable.",
    simpleTitle: "Simple",
    simpleText: "Lives in the menu bar. Turn it on or off anytime.",
    privateTitle: "Private",
    privateText: "No recording, no uploads, no analytics, no server.",
    sourceTitle: "Open source",
    sourceText: "Built in Swift with Core Audio and local music app automation.",
    permissionsEyebrow: "Permissions",
    permissionsTitle: "Why macOS asks for access.",
    permissionsText: "FlowSound needs a few local permissions to do one job. It does not use a network service.",
    audioTitle: "Audio Capture",
    audioText: "Used to detect whether other apps are producing audio.",
    automationTitle: "Automation",
    automationText: "Used to control the selected music app. Experimental adapters may also need Accessibility for menu commands.",
    loginTitle: "Login Item",
    loginText: "Optional, only if you enable Launch at Login.",
    faqEyebrow: "FAQ",
    faqTitle: "Small answers before you download.",
    faqRecordQ: "Does FlowSound record audio?",
    faqRecordA: "No. FlowSound only computes local audio activity levels.",
    faqUploadQ: "Does it upload anything?",
    faqUploadA: "No. FlowSound has no analytics, no server, and no upload feature.",
    faqSpotifyQ: "Does it work with Spotify?",
    faqSpotifyA: "Yes. FlowSound supports Apple Music and Spotify through local AppleScript.",
    faqOtherPlayersQ: "Can it support other music apps?",
    faqOtherPlayersA: "Apple Music and Spotify are official. Netease Cloud Music is experimental and uses menu commands plus Core Audio output feedback, so it may break if the app menu changes.",
    faqLanguageQ: "Does it support Chinese?",
    faqLanguageA: "Yes. FlowSound supports English and Simplified Chinese, with automatic language selection and a manual preference.",
    faqVersionQ: "Which version should I download?",
    faqVersionA: "Choose the 0.18.0 preview to try the redesigned interface and reliability updates. The previous stable channel remains at 0.15.1. Read each release’s installation notes before opening it.",
    faqMacOSQ: "Does it work on macOS 26 and 27?",
    faqMacOSA: "FlowSound targets macOS 15 and later. A user reported that 0.17.0 runs on macOS 26; 0.18.0 has been built and its native interface reviewed on macOS 26. Building with the macOS 27 SDK does not establish macOS 27 runtime compatibility, which still needs testing.",
    faqWarningQ: "Why does macOS warn me when opening it?",
    faqWarningA: "The 0.18.0 preview is ad-hoc signed and not notarized by Apple. Gatekeeper may block it on first open. Review the GitHub release notes and checksum before deciding whether to run it.",
    footerPrivacy: "Privacy",
    footerSecurity: "Security",
    footerGitHub: "GitHub"
  },
  zh: {
    navWhatsNew: "新版亮点",
    navDemo: "演示",
    navPrivacy: "隐私",
    navPermissions: "权限",
    eyebrow: "开源 macOS 菜单栏应用",
    heroTitle: "让音乐知道什么时候该退到一边。",
    heroText: "当其他 App 播放声音时，FlowSound 会自动淡出并暂停 Apple Music 或 Spotify；安静后再恢复到之前的音量。网易云音乐以实验适配器形式提供。",
    downloadPreview: "体验 0.18.0 预览版",
    downloadStable: "下载稳定版 0.15.1",
    previewNote: "0.18.0 为公开预览版，采用 ad-hoc 签名，尚未经过 Apple 公证。首次打开可能被 macOS 拦截。macOS 27 实机运行仍待验证。",
    heroNote: "适用于 macOS 15+。官方支持 Apple Music 和 Spotify，实验支持网易云音乐。本地运行，无分析统计。",
    productHuntLabel: "已收录于",
    focusKicker: "音乐 App 的 Audio Focus",
    focusTitle: "不叠音轨，也不突然安静。",
    withoutTitle: "没有 FlowSound",
    withoutBadge: "手动处理",
    withTitle: "使用 FlowSound",
    withBadge: "自动完成",
    appleMusicLabel: "Apple Music / Spotify / 网易云",
    otherAudioLabel: "视频 / 其他音频",
    withoutText: "两个音轨会叠在一起，直到你手动暂停其中一个。",
    withText: "音乐自动退到一边，结束后从暂停的位置自然回来。",
    eventFade: "淡出",
    eventPause: "暂停",
    eventResume: "恢复",
    focusOutcome: "避免多重音轨。避免突然安静。保持专注和 Flow。",
    releaseEyebrow: "0.18.0 新版亮点 · 公开预览版",
    releaseTitle: "每项设置，都清晰有序。",
    releaseText: "原生控件、舒适的间距，让你更轻松地决定哪些应用可以打断音乐。",
    screenshotLinkLabel: "查看完整尺寸的设置界面截图",
    screenshotAlt: "FlowSound 应用规则界面，监听的 App 和忽略的 App 分为两列管理",
    screenshotCaption: "macOS 26 上的原生界面，使用示例规则。点击查看完整尺寸。",
    rulesTitle: "两列管理，一目了然。",
    rulesText: "监听与忽略的应用各自成列，图标直观、控件对齐。所有修改都在保存后生效。",
    timingTitle: "节奏，恰到好处。",
    timingText: "在独立的“声音调节”页面中，用熟悉的滑块调整淡入淡出和安静等待时间，也可以输入精确数值。",
    reliabilityTitle: "运行状态，清楚可见。",
    reliabilityText: "在诊断中查看监听和权限状态。音频设备切换、睡眠唤醒后可自动恢复监听，播放控制也会尊重可观察到的手动操作。",
    releaseNotes: "查看预览版更新说明 →",
    demoEyebrow: "演示",
    demoTitle: "看看 FlowSound 如何响应其他声音。",
    demoText: "菜单栏应用会检测其他 App 的音频活动，淡出并暂停你选择的音乐 App，然后恢复之前的音量。",
    trustEyebrow: "信任",
    trustTitle: "简单、本地、可审计。",
    simpleTitle: "简单",
    simpleText: "常驻菜单栏。随时开启或关闭。",
    privateTitle: "隐私",
    privateText: "不录音、不上传、无分析统计、无服务器。",
    sourceTitle: "开源",
    sourceText: "使用 Swift、Core Audio 和本地音乐 App 自动化构建。",
    permissionsEyebrow: "权限",
    permissionsTitle: "为什么 macOS 会请求权限。",
    permissionsText: "FlowSound 只需要几个本地权限来完成一件事。它不使用网络服务。",
    audioTitle: "音频捕获",
    audioText: "用于检测其他 App 是否正在输出声音。",
    automationTitle: "自动化",
    automationText: "用于控制选中的音乐 App。实验适配器可能还需要辅助功能权限来点击菜单命令。",
    loginTitle: "登录项",
    loginText: "可选，仅在你启用开机启动时使用。",
    faqEyebrow: "常见问题",
    faqTitle: "下载前的几个简单回答。",
    faqRecordQ: "FlowSound 会录音吗？",
    faqRecordA: "不会。FlowSound 只在本地计算音频活动水平。",
    faqUploadQ: "它会上传任何东西吗？",
    faqUploadA: "不会。FlowSound 没有分析统计、没有服务器，也没有上传功能。",
    faqSpotifyQ: "支持 Spotify 吗？",
    faqSpotifyA: "支持。FlowSound 通过本地 AppleScript 控制 Apple Music 和 Spotify。",
    faqOtherPlayersQ: "可以支持其他音乐 App 吗？",
    faqOtherPlayersA: "Apple Music 和 Spotify 是官方支持。网易云音乐是实验支持，会通过菜单命令和 Core Audio 输出反馈工作；如果菜单结构变化，可能会失效。",
    faqLanguageQ: "支持中文吗？",
    faqLanguageA: "支持。FlowSound 支持英文和简体中文，会按系统语言自动选择，也可以在设置里手动切换。",
    faqVersionQ: "应该下载哪个版本？",
    faqVersionA: "想体验全新界面和可靠性改进，可以选择 0.18.0 预览版。此前的稳定渠道仍为 0.15.1。打开前，请阅读对应版本的安装说明。",
    faqMacOSQ: "支持 macOS 26 和 27 吗？",
    faqMacOSA: "FlowSound 最低支持 macOS 15。已有用户反馈 0.17.0 可在 macOS 26 运行；0.18.0 已在 macOS 26 完成构建和原生界面复核。使用 macOS 27 SDK 构建不等同于实机兼容验证，macOS 27 运行情况仍待测试。",
    faqWarningQ: "为什么打开时 macOS 会提示警告？",
    faqWarningA: "0.18.0 预览版采用 ad-hoc 签名，尚未经过 Apple 公证，Gatekeeper 可能在首次打开时拦截。请先阅读 GitHub 发布说明并核对校验和，再决定是否运行。",
    footerPrivacy: "隐私",
    footerSecurity: "安全",
    footerGitHub: "GitHub"
  }
};

function preferredLanguage() {
  let savedLanguage;
  try {
    savedLanguage = localStorage.getItem("flowsound-language");
  } catch {
    // Browser privacy settings can disable storage; language switching still works.
  }
  if (savedLanguage && translations[savedLanguage]) {
    return savedLanguage;
  }

  const language = navigator.languages?.find((value) => value.toLowerCase().startsWith("zh"))
    || navigator.language;
  return language?.toLowerCase().startsWith("zh") ? "zh" : "en";
}

function applyLanguage(language) {
  const dictionary = translations[language] || translations.en;
  document.documentElement.lang = language === "zh" ? "zh-Hans" : "en";

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const key = element.getAttribute("data-i18n");
    if (dictionary[key]) {
      element.textContent = dictionary[key];
    }
  });

  document.querySelectorAll("[data-lang]").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.lang === language);
    button.setAttribute("aria-pressed", String(button.dataset.lang === language));
  });

  document.querySelectorAll("[data-i18n-alt]").forEach((element) => {
    element.alt = dictionary[element.dataset.i18nAlt];
  });
  document.querySelectorAll("[data-i18n-label]").forEach((element) => {
    element.setAttribute("aria-label", dictionary[element.dataset.i18nLabel]);
  });

  const screenshotLanguage = language === "zh" ? "zh" : "en";
  document.getElementById("settings-screenshot-dark").srcset = `/assets/settings-${screenshotLanguage}-dark.png`;
  document.getElementById("settings-screenshot").src = `/assets/settings-${screenshotLanguage}-light.png`;
  updateScreenshotLink(screenshotLanguage);
}

const colorScheme = window.matchMedia("(prefers-color-scheme: dark)");

function updateScreenshotLink(language) {
  const theme = colorScheme.matches ? "dark" : "light";
  document.getElementById("settings-screenshot-link").href = `/assets/settings-${language}-${theme}.png`;
}

colorScheme.addEventListener("change", () => {
  updateScreenshotLink(document.documentElement.lang === "zh-Hans" ? "zh" : "en");
});

document.querySelectorAll("[data-lang]").forEach((button) => {
  button.addEventListener("click", () => {
    const language = button.dataset.lang;
    try {
      localStorage.setItem("flowsound-language", language);
    } catch {
      // The selected language is still applied for this page view.
    }
    applyLanguage(language);
  });
});

applyLanguage(preferredLanguage());
