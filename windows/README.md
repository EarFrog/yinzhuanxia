# 音转匣 Windows 版

这是音转匣的 Windows/Electron 版本，目标是在 Windows 10/11 上提供和 macOS 版一致的本地音频转换体验。

## 功能

- 支持选择文件、选择文件夹、拖拽添加文件。
- 支持递归扫描常见音频格式和部分 QMC 文件。
- 支持输出格式：原始格式、MP3、FLAC、M4A、OGG、WAV。
- 支持普通音频输入：MP3、FLAC、M4A、AAC、OGG、OPUS、WAV、AIFF、CAF。
- 支持部分 QMC 输入：MFLAC、MGG、QMCFLAC、QMCOGG、QMC0、QMC2、QMC3、BKCMP3、BKCFLAC、TKM 等。
- 支持简体中文、English、日本語、한국어，默认跟随系统。

## 开发运行

在 Windows 上安装 Node.js 22.13+ 后运行：

```powershell
cd windows
npm install
npm start
```

## 打包 Windows 安装包

```powershell
cd windows
npm install
npm run dist
```

输出目录：

```text
windows/dist/
```

## ffmpeg 说明

Windows 版通过 `@ffmpeg-installer/ffmpeg` 获取当前平台可用的 ffmpeg。开发环境也会尝试使用仓库根目录的 `Vendor/ffmpeg/ffmpeg` 作为兜底，方便在 macOS 上预览界面和跑核心测试。

## 限制

部分新版 QQ 音乐 `.mflac/.mgg` 文件需要歌曲对应的 `ekey`。如果文件内或本地缓存中没有可自动读取的 key，程序会显示明确错误，不会静默转码失败。
