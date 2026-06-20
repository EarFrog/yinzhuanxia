# 音转匣

音转匣是一款免费开源的本地音频转换应用，支持普通音频文件在可用格式之间互相转换，也兼容处理部分 QMC 文件。

当前仓库包含两个版本：

- macOS 原生版：`autoMC.xcodeproj`
- Windows/Electron 版：`windows/`

解密核心基于开源项目 [gongjiehong/QMCDecode](https://github.com/gongjiehong/QMCDecode)，原项目 MIT 许可证保留在 `LICENSE`。

## 功能

- 启动后自动递归扫描系统音乐目录中所有支持的音乐格式。
- 支持拖拽文件或文件夹，也可手动添加文件或文件夹。
- 支持批量并发转换。
- 支持自定义输出目录。
- 支持选择输出格式：原始格式、MP3、FLAC、M4A、OGG、WAV。
- 支持普通音频输入：MP3、FLAC、M4A、AAC、OGG、OPUS、WAV、AIFF、CAF。
- 支持多国语言：默认跟随系统，也可手动选择简体中文、English、日本語、한국어。
- 输出文件重名时自动追加数字后缀，避免覆盖。
- 显示每个文件的转换状态、输出文件名和失败原因。
- 底部状态栏会按格式显示已添加文件分布，例如 MP3、FLAC、M4A、MFLAC->FLAC。

## 发布方式

音转匣当前建议先做免费开源/公开测试版，用下载量和反馈验证需求，再决定是否进入 Mac App Store。

- App 内不包含支付、订阅、激活码或 Pro 解锁逻辑。
- macOS 版会自动扫描系统音乐目录；为支持打开即自动获取真实 `~/Music` 内容，当前未启用 App Sandbox。
- 如果后续正式上架，请用 Xcode Archive 上传到 App Store Connect；仓库里的 `.dmg` 只作为本地测试包。

## 支持的 QMC 输入格式

- `.mgg`、`.mgg1`、`.qmcogg` 解密为 `.ogg`
- `.mflac`、`.mflac0`、`.qmcflac`、`.bkcflac` 解密为 `.flac`
- `.qmc0`、`.qmc3`、`.bkcmp3` 解密为 `.mp3`
- `.qmc2` 解密为 `.ogg`
- `.tkm` 解密为 `.m4a`
- 支持部分旧版 QQ 音乐使用的十六进制扩展名

说明：部分新版 QQ 音乐 `.mflac/.mgg` 文件需要对应歌曲的 `ekey` 才能解密。如果文件本身或本地缓存中没有可自动读取的 `ekey`，音转匣会在结果列显示明确错误，而不是继续交给 ffmpeg 转码。

## 支持的普通音频输入格式

- `.mp3`
- `.flac`
- `.m4a`、`.aac`
- `.ogg`、`.opus`
- `.wav`
- `.aif`、`.aiff`、`.aifc`
- `.caf`

## 输出格式说明

选择“原始格式”时，QMC 文件只解密、不额外转码；普通音频文件会复制到输出目录并保留原格式。

选择 MP3、FLAC、M4A、OGG、WAV 时，音转匣会调用随 App 打包的 ffmpeg 转码。内置 ffmpeg 来自 `ffmpeg-static`，其许可证文件会随 App 放在 `Contents/Resources/licenses/ffmpeg/`。

## 两套转换方案

当前项目里保留了两套思路：

- 主 App 方案：Swift 解密 QMC 文件，随后用随 App 打包的 arm64 ffmpeg 转码。这是音转匣默认使用的方案。
- 参考方案：`tools/qmcflac2mp3-reference` 保留了 [alexknight/qmcflac2mp3](https://github.com/alexknight/qmcflac2mp3) 的 Python/Perl 两段式流程，便于对照 `.qmcflac -> .flac -> .mp3` 的实现。它自带的 `decoder` 是 x86_64 二进制，在 Apple Silicon 上可能需要 Rosetta。

## 构建

### macOS

在本目录运行：

```sh
./build_autoMC.sh
```

脚本会构建 Release 版本，并把签名后的应用复制到：

```text
./音转匣.app
```

也可以显式指定配置：

```sh
./build_autoMC.sh Debug
./build_autoMC.sh Release
```

默认输出目录是 `~/Music/音转匣 输出`。

### Windows

在 Windows 10/11 上安装 Node.js 22.13+ 后运行：

```powershell
cd windows
npm install
npm start
```

打包安装包：

```powershell
cd windows
npm run dist
```

Windows 打包产物会输出到：

```text
windows/dist/
```

说明：Windows 版使用 Electron 实现，核心 QMC 解密算法已从 macOS Swift 版移植到 `windows/src/core/`，转码依赖 `@ffmpeg-installer/ffmpeg` 提供的 ffmpeg。
