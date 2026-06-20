"use strict";

const dictionaries = {
  "zh-CN": {
    appTitle: "音转匣",
    subtitle: "免费开源的本地音频转换工具，支持常见音频互转与部分 QMC 文件兼容处理。",
    addFiles: "添加文件",
    chooseOutput: "选择输出目录",
    clear: "清空",
    start: "开始转换",
    inputFormat: "获取格式",
    allFormats: "全部格式",
    outputFormat: "输出格式",
    outputDirectory: "输出目录",
    language: "语言",
    followSystem: "跟随系统",
    empty: "拖拽音乐文件到这里，或选择文件/文件夹。",
    fileName: "文件名",
    format: "格式",
    status: "状态",
    output: "输出",
    groupFiles: "{format} 类型  {count} 个文件",
    waiting: "等待",
    converting: "转换中",
    success: "完成",
    failed: "失败",
    items: "已添加 {count} 个文件",
    breakdown: "格式：{breakdown}",
    defaultOutput: "默认输出到“音乐/音转匣 输出”。"
  },
  en: {
    appTitle: "Yinzhuanxia",
    subtitle: "Free open-source local audio converter with common audio conversion and partial QMC support.",
    addFiles: "Add Files",
    chooseOutput: "Output Folder",
    clear: "Clear",
    start: "Convert",
    inputFormat: "Get Format",
    allFormats: "All Formats",
    outputFormat: "Output Format",
    outputDirectory: "Output Folder",
    language: "Language",
    followSystem: "Follow System",
    empty: "Drop audio files here, or choose files/folders.",
    fileName: "File",
    format: "Format",
    status: "Status",
    output: "Output",
    groupFiles: "{format} Type  {count} file(s)",
    waiting: "Waiting",
    converting: "Converting",
    success: "Done",
    failed: "Failed",
    items: "{count} file(s) added",
    breakdown: "Formats: {breakdown}",
    defaultOutput: "Default output is Music/Yinzhuanxia Output."
  },
  ja: {
    appTitle: "音転箱",
    subtitle: "無料オープンソースのローカル音声変換ツール。一般的な音声形式と一部 QMC に対応します。",
    addFiles: "ファイル追加",
    chooseOutput: "出力先",
    clear: "クリア",
    start: "変換開始",
    inputFormat: "取得形式",
    allFormats: "すべての形式",
    outputFormat: "出力形式",
    outputDirectory: "出力先",
    language: "言語",
    followSystem: "システムに従う",
    empty: "音楽ファイルをドロップ、またはファイル/フォルダを選択してください。",
    fileName: "ファイル",
    format: "形式",
    status: "状態",
    output: "出力",
    groupFiles: "{format} 形式  {count} 件",
    waiting: "待機",
    converting: "変換中",
    success: "完了",
    failed: "失敗",
    items: "{count} 件追加",
    breakdown: "形式：{breakdown}",
    defaultOutput: "既定の出力先は Music/Yinzhuanxia Output です。"
  },
  ko: {
    appTitle: "음전함",
    subtitle: "무료 오픈소스 로컬 오디오 변환 도구입니다. 일반 오디오 변환과 일부 QMC 파일을 지원합니다.",
    addFiles: "파일 추가",
    chooseOutput: "출력 폴더",
    clear: "비우기",
    start: "변환 시작",
    inputFormat: "가져올 형식",
    allFormats: "모든 형식",
    outputFormat: "출력 형식",
    outputDirectory: "출력 폴더",
    language: "언어",
    followSystem: "시스템 설정",
    empty: "음악 파일을 드래그하거나 파일/폴더를 선택하세요.",
    fileName: "파일",
    format: "형식",
    status: "상태",
    output: "출력",
    groupFiles: "{format} 형식  {count}개 파일",
    waiting: "대기",
    converting: "변환 중",
    success: "완료",
    failed: "실패",
    items: "{count}개 파일 추가됨",
    breakdown: "형식: {breakdown}",
    defaultOutput: "기본 출력 위치는 Music/Yinzhuanxia Output 입니다."
  }
};

function resolveLanguage(requested, systemLocale = "zh-CN") {
  if (requested && requested !== "system" && dictionaries[requested]) return requested;
  const normalized = (systemLocale || "zh-CN").toLowerCase();
  if (normalized.startsWith("zh")) return "zh-CN";
  if (normalized.startsWith("ja")) return "ja";
  if (normalized.startsWith("ko")) return "ko";
  return "en";
}

function getDictionary(language, systemLocale) {
  return dictionaries[resolveLanguage(language, systemLocale)] || dictionaries["zh-CN"];
}

module.exports = { dictionaries, resolveLanguage, getDictionary };
