import Foundation

enum OutputFormat: String, CaseIterable {
    case original
    case mp3
    case flac
    case m4a
    case ogg
    case wav

    var localizedTitle: String {
        L10n.tr("format.\(rawValue)")
    }

    var fileExtension: String? {
        switch self {
        case .original:
            return nil
        case .mp3:
            return "mp3"
        case .flac:
            return "flac"
        case .m4a:
            return "m4a"
        case .ogg:
            return "ogg"
        case .wav:
            return "wav"
        }
    }
}

enum AudioTranscoderError: LocalizedError {
    case missingFFmpeg(format: OutputFormat)
    case missingAFConvert
    case conversionFailed(tool: String, details: String)

    var errorDescription: String? {
        switch self {
        case .missingFFmpeg(let format):
            return L10n.tr("error.missingFFmpeg", format.localizedTitle)
        case .missingAFConvert:
            return L10n.tr("error.missingAFConvert")
        case .conversionFailed(let tool, let details):
            return L10n.tr("error.conversionFailed", tool, details)
        }
    }
}

final class AudioTranscoder {
    private let fileManager = FileManager.default

    func write(
        inputURL: URL,
        outputDirectory: URL,
        format: OutputFormat
    ) throws -> URL {
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let originalExtension = inputURL.pathExtension.lowercased()
        let inputExtension = normalizedAudioExtension(originalExtension)
        let targetExtension = format.fileExtension ?? originalExtension
        let outputURL = uniqueOutputURL(
            directory: outputDirectory,
            baseName: inputURL.deletingPathExtension().lastPathComponent,
            fileExtension: targetExtension
        )

        if format == .original || format.fileExtension == inputExtension {
            try fileManager.copyItem(at: inputURL, to: outputURL)
            return outputURL
        }

        guard let ffmpeg = findExecutable(named: "ffmpeg") else {
            throw AudioTranscoderError.missingFFmpeg(format: format)
        }
        try runFFmpeg(ffmpeg, inputURL: inputURL, outputURL: outputURL, format: format)
        return outputURL
    }

    func write(
        decryptedAudio: (data: Data, fileExtension: String),
        sourceURL: URL,
        outputDirectory: URL,
        format: OutputFormat
    ) throws -> URL {
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        if format == .original || format.fileExtension == decryptedAudio.fileExtension {
            let outputURL = uniqueOutputURL(
                directory: outputDirectory,
                baseName: sourceURL.deletingPathExtension().lastPathComponent,
                fileExtension: decryptedAudio.fileExtension
            )
            try decryptedAudio.data.write(to: outputURL, options: .atomic)
            return outputURL
        }

        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("autoMC-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }

        let inputURL = tempDirectory
            .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(decryptedAudio.fileExtension)
        try decryptedAudio.data.write(to: inputURL, options: .atomic)

        let outputURL = uniqueOutputURL(
            directory: outputDirectory,
            baseName: sourceURL.deletingPathExtension().lastPathComponent,
            fileExtension: format.fileExtension ?? decryptedAudio.fileExtension
        )

        switch format {
        case .mp3:
            guard let ffmpeg = findExecutable(named: "ffmpeg") else {
                throw AudioTranscoderError.missingFFmpeg(format: format)
            }
            try runFFmpeg(ffmpeg, inputURL: inputURL, outputURL: outputURL, format: format)
        case .flac, .m4a, .wav:
            if let ffmpeg = findExecutable(named: "ffmpeg") {
                try runFFmpeg(ffmpeg, inputURL: inputURL, outputURL: outputURL, format: format)
            } else {
                try runAFConvert(inputURL: inputURL, outputURL: outputURL, format: format)
            }
        case .ogg:
            guard let ffmpeg = findExecutable(named: "ffmpeg") else {
                throw AudioTranscoderError.missingFFmpeg(format: format)
            }
            try runFFmpeg(ffmpeg, inputURL: inputURL, outputURL: outputURL, format: format)
        case .original:
            break
        }

        return outputURL
    }

    private func runFFmpeg(_ executable: String, inputURL: URL, outputURL: URL, format: OutputFormat) throws {
        var arguments = ["-y", "-i", inputURL.path]
        switch format {
        case .mp3:
            arguments += ["-codec:a", "libmp3lame", "-q:a", "2"]
        case .flac:
            arguments += ["-codec:a", "flac"]
        case .m4a:
            arguments += ["-codec:a", "aac", "-b:a", "256k"]
        case .ogg:
            arguments += ["-codec:a", "libvorbis", "-q:a", "6"]
        case .wav:
            arguments += ["-codec:a", "pcm_s16le"]
        case .original:
            break
        }
        arguments.append(outputURL.path)
        try runProcess(executable: executable, arguments: arguments, toolName: "ffmpeg")
    }

    private func runAFConvert(inputURL: URL, outputURL: URL, format: OutputFormat) throws {
        guard let afconvert = findExecutable(named: "afconvert") else {
            throw AudioTranscoderError.missingAFConvert
        }

        let arguments: [String]
        switch format {
        case .flac:
            arguments = ["-f", "flac", "-d", "flac", inputURL.path, outputURL.path]
        case .m4a:
            arguments = ["-f", "m4af", "-d", "aac", "-b", "256000", inputURL.path, outputURL.path]
        case .wav:
            arguments = ["-f", "WAVE", "-d", "LEI16", inputURL.path, outputURL.path]
        default:
            throw AudioTranscoderError.missingFFmpeg(format: format)
        }

        try runProcess(executable: afconvert, arguments: arguments, toolName: "afconvert")
    }

    private func runProcess(executable: String, arguments: [String], toolName: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let details = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AudioTranscoderError.conversionFailed(tool: toolName, details: details)
        }
    }

    private func findExecutable(named name: String) -> String? {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL
                .appendingPathComponent("bin", isDirectory: true)
                .appendingPathComponent(name)
                .path
            if fileManager.isExecutableFile(atPath: bundled) {
                return bundled
            }
        }

        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]
        return candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    private func normalizedAudioExtension(_ fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "aif", "aiff", "aifc":
            return "aiff"
        default:
            return fileExtension.lowercased()
        }
    }

    private func uniqueOutputURL(directory: URL, baseName: String, fileExtension: String) -> URL {
        let first = directory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        guard fileManager.fileExists(atPath: first.path) else {
            return first
        }

        var index = 2
        while true {
            let candidate = directory
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(fileExtension)
            if fileManager.fileExists(atPath: candidate.path) == false {
                return candidate
            }
            index += 1
        }
    }
}
