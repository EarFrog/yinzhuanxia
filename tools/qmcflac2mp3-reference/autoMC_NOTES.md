# qmcflac2mp3 参考方案

这里保留的是 [alexknight/qmcflac2mp3](https://github.com/alexknight/qmcflac2mp3) 的参考实现，用来对照 autoMC 的主转换链。

它采用两段式流程：

1. `.qmcflac` 解密为 `.flac`
2. `.flac` 转换为 `.mp3`

注意：`tools/qmc2flac/decoder` 是 macOS x86_64 二进制。在 Apple Silicon Mac 上可能需要 Rosetta。autoMC 主 App 不依赖这个二进制，主 App 使用 Swift 解密逻辑和随 App 打包的 arm64 ffmpeg。

示例：

```sh
./tools/qmcflac2mp3-reference/run_qmcflac2mp3.sh -i /path/to/qmcflac_dir -o /path/to/mp3_dir -m qmc2mp3
```
