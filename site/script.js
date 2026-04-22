const translations = {
  en: {
    navDemo: "Demo",
    navPrivacy: "Privacy",
    navPermissions: "Permissions",
    eyebrow: "Open-source macOS menu bar app",
    heroTitle: "Music that knows when to step aside.",
    heroText: "FlowSound fades and pauses Apple Music or Spotify when other apps play audio, then restores it when things become quiet again.",
    download: "Download for macOS",
    github: "View on GitHub",
    heroNote: "Built for macOS 15+. Apple Music and Spotify. English and Chinese. Local-first, no analytics.",
    productHuntLabel: "Featured on",
    focusKicker: "Audio focus for your music app",
    focusTitle: "No overlap. No sudden silence.",
    withoutTitle: "Without FlowSound",
    withoutBadge: "manual",
    withTitle: "With FlowSound",
    withBadge: "automatic",
    appleMusicLabel: "Apple Music / Spotify",
    otherAudioLabel: "Video / other audio",
    withoutText: "Two soundtracks compete until you pause one by hand.",
    withText: "Music steps aside, then returns from the same paused position.",
    eventFade: "fade out",
    eventPause: "pause",
    eventResume: "resume",
    focusOutcome: "Avoid overlapping audio. Avoid sudden silence. Stay in flow.",
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
    automationText: "Used to control Apple Music or Spotify volume and playback.",
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
    faqOtherPlayersA: "Apple Music and Spotify are supported today. Other apps can be adapted if they expose reliable local playback and volume control.",
    faqLanguageQ: "Does it support Chinese?",
    faqLanguageA: "Yes. FlowSound supports English and Simplified Chinese, with automatic language selection and a manual preference.",
    faqWarningQ: "Why does macOS warn me when opening it?",
    faqWarningA: "Current builds are ad-hoc signed tester builds until a Developer ID notarized release is available.",
    footerPrivacy: "Privacy",
    footerSecurity: "Security",
    footerGitHub: "GitHub"
  },
  zh: {
    navDemo: "演示",
    navPrivacy: "隐私",
    navPermissions: "权限",
    eyebrow: "开源 macOS 菜单栏应用",
    heroTitle: "让音乐知道什么时候该退到一边。",
    heroText: "当其他 App 播放声音时，FlowSound 会自动淡出并暂停 Apple Music 或 Spotify；安静后再恢复到之前的音量。",
    download: "下载 macOS 版",
    github: "查看 GitHub",
    heroNote: "适用于 macOS 15+。支持 Apple Music 和 Spotify。支持中文和英文。本地运行，无分析统计。",
    productHuntLabel: "已收录于",
    focusKicker: "音乐 App 的 Audio Focus",
    focusTitle: "不叠音轨，也不突然安静。",
    withoutTitle: "没有 FlowSound",
    withoutBadge: "手动处理",
    withTitle: "使用 FlowSound",
    withBadge: "自动完成",
    appleMusicLabel: "Apple Music / Spotify",
    otherAudioLabel: "视频 / 其他音频",
    withoutText: "两个音轨会叠在一起，直到你手动暂停其中一个。",
    withText: "音乐自动退到一边，结束后从暂停的位置自然回来。",
    eventFade: "淡出",
    eventPause: "暂停",
    eventResume: "恢复",
    focusOutcome: "避免多重音轨。避免突然安静。保持专注和 Flow。",
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
    automationText: "用于控制 Apple Music 或 Spotify 的音量和播放状态。",
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
    faqOtherPlayersA: "当前版本支持 Apple Music 和 Spotify。如果其他 App 提供可靠的本地播放和音量控制能力，也可以继续适配。",
    faqLanguageQ: "支持中文吗？",
    faqLanguageA: "支持。FlowSound 支持英文和简体中文，会按系统语言自动选择，也可以在偏好设置里手动切换。",
    faqWarningQ: "为什么打开时 macOS 会提示警告？",
    faqWarningA: "当前构建是 ad-hoc 签名的测试版本，之后有 Developer ID notarized 版本后会减少这类提示。",
    footerPrivacy: "隐私",
    footerSecurity: "安全",
    footerGitHub: "GitHub"
  }
};

function preferredLanguage() {
  const savedLanguage = localStorage.getItem("flowsound-language");
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
  });
}

document.querySelectorAll("[data-lang]").forEach((button) => {
  button.addEventListener("click", () => {
    const language = button.dataset.lang;
    localStorage.setItem("flowsound-language", language);
    applyLanguage(language);
  });
});

applyLanguage(preferredLanguage());
