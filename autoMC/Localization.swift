import Foundation

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}

enum AppLanguage: String, CaseIterable {
    case system
    case zhHans
    case en
    case ja
    case ko

    private static let storageKey = "app.language"

    static var selected: AppLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
                  let language = AppLanguage(rawValue: rawValue) else {
                return .system
            }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
            NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
        }
    }

    static var current: AppLanguage {
        let selected = AppLanguage.selected
        guard selected == .system else {
            return selected
        }

        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferred.hasPrefix("zh") {
            return .zhHans
        }
        if preferred.hasPrefix("ja") {
            return .ja
        }
        if preferred.hasPrefix("ko") {
            return .ko
        }
        return .en
    }

    var menuTitle: String {
        switch self {
        case .system:
            return L10n.tr("language.system")
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        case .ja:
            return "日本語"
        case .ko:
            return "한국어"
        }
    }
}

enum L10n {
    static func tr(_ key: String) -> String {
        translations[AppLanguage.current]?[key]
            ?? translations[.en]?[key]
            ?? key
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), arguments: arguments)
    }

    private static let translations: [AppLanguage: [String: String]] = [
        .zhHans: [
            "app.name": "音转匣",
            "app.subtitle": "免费开源的本地音频转换工具，支持常见音频互转与部分 QMC 文件兼容处理。",
            "drop.title": "拖入 QMC、音频文件或文件夹",
            "formats.short": "支持 QMC 与常见音频格式，可输出为原始格式、MP3、FLAC、M4A、OGG 或 WAV。",
            "button.addFiles": "添加文件",
            "button.addFolder": "添加文件夹",
            "button.output": "输出位置...",
            "button.clear": "清空",
            "button.convert": "开始转换",
            "button.convertSelected": "转换选中",
            "label.format": "格式：",
            "label.inputFormat": "获取：",
            "label.language": "语言：",
            "label.outputDirectory": "输出目录：",
            "language.system": "跟随系统",
            "status.waiting": "等待中",
            "status.running": "转换中",
            "status.success": "已完成",
            "status.failed": "失败",
            "table.file": "文件",
            "table.select": "选择",
            "table.status": "状态",
            "table.result": "结果",
            "table.path": "路径",
            "table.group": "%@ 类型  %d 个文件",
            "summary.empty": "暂无待转换文件。%@",
            "summary.scanning": "正在自动扫描音乐目录...",
            "summary.items": "已添加 %d 个文件。输出：%@。目标：%@。格式分布：%@",
            "alert.noFiles.title": "没有可转换的文件",
            "alert.noFiles.message": "请先添加支持的 QMC 或普通音频文件。",
            "alert.done.title": "转换完成",
            "alert.done.message": "成功：%d，失败：%d。",
            "format.all": "全部格式",
            "format.original": "原始格式",
            "format.mp3": "MP3",
            "format.flac": "FLAC",
            "format.m4a": "M4A",
            "format.ogg": "OGG",
            "format.wav": "WAV",
            "menu.about": "关于 音转匣",
            "menu.hide": "隐藏 音转匣",
            "menu.hideOthers": "隐藏其他应用",
            "menu.quit": "退出 音转匣",
            "error.missingFFmpeg": "转换为 %@ 需要 ffmpeg。",
            "error.missingAFConvert": "未找到系统转换工具 afconvert。",
            "error.conversionFailed": "%@ 转换失败。%@",
            "error.unsupportedExtension": "不支持的文件扩展名：.%@",
            "error.cannotReadFile": "无法读取输入文件。",
            "error.cannotOpenStream": "无法打开输入文件流。",
            "error.cannotGetLength": "无法获取输入文件大小。",
            "error.cannotReadSize": "无法读取密钥长度数据。",
            "error.cannotReadRawKey": "无法读取原始密钥数据。",
            "error.searchRawKeyFailed": "未找到密钥结束标记。",
            "error.unsupportedEncryptedKey": "解密后的音频数据无效。这个文件可能是新版 QQ 音乐 .mflac/.mgg 加密，需要对应 ekey；当前文件没有可自动读取的 ekey。"
        ],
        .en: [
            "app.name": "AudioBox",
            "app.subtitle": "A free open-source local audio converter for common formats and compatible QMC files.",
            "drop.title": "Drop QMC files, audio files, or folders",
            "formats.short": "Supports QMC and common audio files. Export as original, MP3, FLAC, M4A, OGG, or WAV.",
            "button.addFiles": "Add Files",
            "button.addFolder": "Add Folder",
            "button.output": "Output...",
            "button.clear": "Clear",
            "button.convert": "Convert",
            "button.convertSelected": "Convert Selected",
            "label.format": "Format:",
            "label.inputFormat": "Get:",
            "label.language": "Language:",
            "label.outputDirectory": "Output:",
            "language.system": "Follow System",
            "status.waiting": "Waiting",
            "status.running": "Converting",
            "status.success": "Done",
            "status.failed": "Failed",
            "table.file": "File",
            "table.select": "Select",
            "table.status": "Status",
            "table.result": "Result",
            "table.path": "Path",
            "table.group": "%@ Type  %d file(s)",
            "summary.empty": "No files added. %@",
            "summary.scanning": "Scanning your Music folder...",
            "summary.items": "%d file(s) added. Output: %@. Target: %@. Formats: %@",
            "alert.noFiles.title": "No Convertible Files",
            "alert.noFiles.message": "Please add supported QMC or regular audio files first.",
            "alert.done.title": "Conversion Complete",
            "alert.done.message": "Succeeded: %d, failed: %d.",
            "format.all": "All Formats",
            "format.original": "Original",
            "format.mp3": "MP3",
            "format.flac": "FLAC",
            "format.m4a": "M4A",
            "format.ogg": "OGG",
            "format.wav": "WAV",
            "menu.about": "About AudioBox",
            "menu.hide": "Hide AudioBox",
            "menu.hideOthers": "Hide Others",
            "menu.quit": "Quit AudioBox",
            "error.missingFFmpeg": "Converting to %@ requires ffmpeg.",
            "error.missingAFConvert": "System converter afconvert was not found.",
            "error.conversionFailed": "%@ conversion failed. %@",
            "error.unsupportedExtension": "Unsupported file extension: .%@",
            "error.cannotReadFile": "Could not read the input file.",
            "error.cannotOpenStream": "Could not open the input stream.",
            "error.cannotGetLength": "Could not get the input file size.",
            "error.cannotReadSize": "Could not read key length data.",
            "error.cannotReadRawKey": "Could not read raw key data.",
            "error.searchRawKeyFailed": "Could not find the key terminator.",
            "error.unsupportedEncryptedKey": "The decrypted audio data is invalid. This may be a newer QQ Music .mflac/.mgg file that requires its matching ekey; no readable ekey was found."
        ],
        .ja: [
            "app.name": "音転箱",
            "app.subtitle": "一般的な音声形式と一部の QMC ファイルに対応した無料のオープンソース変換ツールです。",
            "drop.title": "QMC、音声ファイル、またはフォルダをドロップ",
            "formats.short": "QMC と一般的な音声形式に対応。元形式、MP3、FLAC、M4A、OGG、WAV で出力できます。",
            "button.addFiles": "ファイル追加",
            "button.addFolder": "フォルダ追加",
            "button.output": "出力先...",
            "button.clear": "クリア",
            "button.convert": "変換開始",
            "button.convertSelected": "選択を変換",
            "label.format": "形式：",
            "label.inputFormat": "取得：",
            "label.language": "言語：",
            "label.outputDirectory": "出力先：",
            "language.system": "システムに従う",
            "status.waiting": "待機中",
            "status.running": "変換中",
            "status.success": "完了",
            "status.failed": "失敗",
            "table.file": "ファイル",
            "table.select": "選択",
            "table.status": "状態",
            "table.result": "結果",
            "table.path": "パス",
            "table.group": "%@ 形式  %d 件",
            "summary.empty": "変換対象はありません。%@",
            "summary.scanning": "音楽フォルダを自動スキャン中...",
            "summary.items": "%d 個のファイルを追加済み。出力：%@。変換先：%@。形式分布：%@",
            "alert.noFiles.title": "変換できるファイルがありません",
            "alert.noFiles.message": "対応する QMC または通常の音声ファイルを追加してください。",
            "alert.done.title": "変換完了",
            "alert.done.message": "成功：%d、失敗：%d。",
            "format.all": "すべての形式",
            "format.original": "元の形式",
            "format.mp3": "MP3",
            "format.flac": "FLAC",
            "format.m4a": "M4A",
            "format.ogg": "OGG",
            "format.wav": "WAV",
            "menu.about": "音転箱について",
            "menu.hide": "音転箱を隠す",
            "menu.hideOthers": "ほかを隠す",
            "menu.quit": "音転箱を終了",
            "error.missingFFmpeg": "%@ への変換には ffmpeg が必要です。",
            "error.missingAFConvert": "システム変換ツール afconvert が見つかりません。",
            "error.conversionFailed": "%@ の変換に失敗しました。%@",
            "error.unsupportedExtension": "未対応の拡張子：.%@",
            "error.cannotReadFile": "入力ファイルを読み取れません。",
            "error.cannotOpenStream": "入力ストリームを開けません。",
            "error.cannotGetLength": "入力ファイルサイズを取得できません。",
            "error.cannotReadSize": "キー長データを読み取れません。",
            "error.cannotReadRawKey": "元のキーデータを読み取れません。",
            "error.searchRawKeyFailed": "キー終端マークが見つかりません。",
            "error.unsupportedEncryptedKey": "復号後の音声データが無効です。このファイルは新しい QQ Music .mflac/.mgg 暗号化形式で、対応する ekey が必要な可能性があります。読み取れる ekey は見つかりません。"
        ],
        .ko: [
            "app.name": "오디오상자",
            "app.subtitle": "일반 오디오와 일부 QMC 파일을 지원하는 무료 오픈소스 로컬 변환 도구입니다.",
            "drop.title": "QMC, 오디오 파일 또는 폴더를 끌어오세요",
            "formats.short": "QMC와 일반 오디오 형식을 지원하며 원본, MP3, FLAC, M4A, OGG, WAV로 출력할 수 있습니다.",
            "button.addFiles": "파일 추가",
            "button.addFolder": "폴더 추가",
            "button.output": "출력 위치...",
            "button.clear": "비우기",
            "button.convert": "변환 시작",
            "button.convertSelected": "선택 변환",
            "label.format": "형식:",
            "label.inputFormat": "가져오기:",
            "label.language": "언어:",
            "label.outputDirectory": "출력:",
            "language.system": "시스템 따르기",
            "status.waiting": "대기 중",
            "status.running": "변환 중",
            "status.success": "완료",
            "status.failed": "실패",
            "table.file": "파일",
            "table.select": "선택",
            "table.status": "상태",
            "table.result": "결과",
            "table.path": "경로",
            "table.group": "%@ 형식  %d개 파일",
            "summary.empty": "변환할 파일이 없습니다. %@",
            "summary.scanning": "음악 폴더를 자동으로 스캔 중...",
            "summary.items": "%d개 파일 추가됨. 출력: %@. 대상: %@. 형식 분포: %@",
            "alert.noFiles.title": "변환할 파일 없음",
            "alert.noFiles.message": "지원되는 QMC 또는 일반 오디오 파일을 먼저 추가하세요.",
            "alert.done.title": "변환 완료",
            "alert.done.message": "성공: %d, 실패: %d.",
            "format.all": "모든 형식",
            "format.original": "원본 형식",
            "format.mp3": "MP3",
            "format.flac": "FLAC",
            "format.m4a": "M4A",
            "format.ogg": "OGG",
            "format.wav": "WAV",
            "menu.about": "오디오상자 정보",
            "menu.hide": "오디오상자 숨기기",
            "menu.hideOthers": "다른 앱 숨기기",
            "menu.quit": "오디오상자 종료",
            "error.missingFFmpeg": "%@ 변환에는 ffmpeg가 필요합니다.",
            "error.missingAFConvert": "시스템 변환 도구 afconvert를 찾을 수 없습니다.",
            "error.conversionFailed": "%@ 변환 실패. %@",
            "error.unsupportedExtension": "지원하지 않는 확장자: .%@",
            "error.cannotReadFile": "입력 파일을 읽을 수 없습니다.",
            "error.cannotOpenStream": "입력 스트림을 열 수 없습니다.",
            "error.cannotGetLength": "입력 파일 크기를 가져올 수 없습니다.",
            "error.cannotReadSize": "키 길이 데이터를 읽을 수 없습니다.",
            "error.cannotReadRawKey": "원본 키 데이터를 읽을 수 없습니다.",
            "error.searchRawKeyFailed": "키 종료 표시를 찾을 수 없습니다.",
            "error.unsupportedEncryptedKey": "복호화된 오디오 데이터가 올바르지 않습니다. 이 파일은 대응 ekey가 필요한 새 QQ Music .mflac/.mgg 암호화 파일일 수 있으며, 읽을 수 있는 ekey를 찾지 못했습니다."
        ]
    ]
}
