//
//  QMCDecoder.swift
//  QMCDecode
//
//  Created by 龚杰洪 on 2022/1/10.
//  Copyright © 2022 龚杰洪. All rights reserved.
//

import Foundation

class QMDecoder {
    enum DecoderError: Error {
        case unsupportFileExtension(ext: String)
        case canNotReadFile
        case canNotReadFileByStream
        case canNotGetFileLength
        case canNotReadSizeBuffer
        case canNotReadRawKeyBuffer
        case searchRawKeyFailed
        case unsupportedEncryptedKey
    }

    private let commaASCIICode: UInt8 = Character(",").asciiValue ?? 44


    private let originFilePath: String
    private let outputDirectory: String
    private let readStream: InputStream
    private let originFileLength: Int
    private var encryptedAudioLength: Int

    private var realAudioSize: Int = 0

    private var cipher: QMCipher?

    init(originFilePath: String, outputDirectory: String) throws {
        self.originFilePath = originFilePath
        self.outputDirectory = outputDirectory
        guard let fileStream = InputStream(fileAtPath: originFilePath) else {
            throw DecoderError.canNotReadFileByStream
        }
        self.readStream = fileStream

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: originFilePath)
        guard let fileLength = fileAttributes[FileAttributeKey.size] as? Int else {
            throw DecoderError.canNotGetFileLength
        }
        self.originFileLength = fileLength
        self.encryptedAudioLength = fileLength

        try searchKey()
    }

    @discardableResult
    func decryptAndWriteToFile(outputExtension: String? = nil) throws -> URL {
        let decrypted = try decryptedAudioData()
        let fileURL = URL(fileURLWithPath: originFilePath)
        let targetExtension = outputExtension ?? decrypted.fileExtension

        var outputURL = URL(fileURLWithPath: self.outputDirectory)
        outputURL.appendPathComponent(fileURL.lastPathComponent)
        outputURL.deletePathExtension()
        outputURL.appendPathExtension(targetExtension)
        outputURL = uniqueOutputURL(for: outputURL)
        try decrypted.data.write(to: outputURL, options: Data.WritingOptions.atomic)
        return outputURL
    }

    func decryptedAudioData() throws -> (data: Data, fileExtension: String) {
        let fileURL = URL(fileURLWithPath: originFilePath)
        let fileExtension = fileURL.pathExtension.lowercased()
        if fileExtension.count > 0, let extAndVersion = encryptExtDictionary[fileExtension], let cipher = self.cipher {
            let fileHandle = FileHandle(forReadingAtPath: originFilePath)
            if let fileData = try fileHandle?.read(upToCount: self.realAudioSize) {
                let decodeData = cipher.qmDecrypt(data: fileData, offset: 0)
                guard isValidAudioHeader(decodeData, fileExtension: extAndVersion.ext) else {
                    throw DecoderError.unsupportedEncryptedKey
                }
                return (decodeData, extAndVersion.ext)
            } else {
                throw DecoderError.canNotReadFile
            }
        } else {
            throw DecoderError.unsupportFileExtension(ext: fileExtension)
        }
    }

    func matchingDecoder(_ extAndVersion: ExtensionAndVersion) throws {
        if extAndVersion.version == .v2 {

        } else {

        }
    }

    func searchKey() throws {
        guard let fileHandle = FileHandle(forReadingAtPath: originFilePath) else {
            throw DecoderError.canNotReadFile
        }
        defer {
            try? fileHandle.close()
        }

        self.encryptedAudioLength = try detectEncryptedAudioLength(fileHandle: fileHandle)

        try fileHandle.seek(toOffset: UInt64(self.encryptedAudioLength - 4))
        guard let lastFourBytes = try fileHandle.read(upToCount: 4) else {
            throw DecoderError.canNotReadFile
        }

        // 移动端下载的用,以QTag结尾
        if String(bytes: lastFourBytes, encoding: String.Encoding.utf8) == "QTag" {
            // 读取key长度
            try fileHandle.seek(toOffset: UInt64(self.originFileLength - 8))
            guard let sizeBuffer = try fileHandle.read(upToCount: 4) else {
                throw DecoderError.canNotReadFile
            }
            let keySize = sizeBuffer.withUnsafeBytes {
                $0.load(as: UInt32.self).bigEndian
            }

            // 计算真实音频长度
            self.realAudioSize = self.originFileLength - Int(keySize) - 8

            // 读取原始key
            try fileHandle.seek(toOffset: UInt64(self.realAudioSize))
            guard let rawKey = try fileHandle.read(upToCount: Int(keySize)) else {
                throw DecoderError.canNotReadRawKeyBuffer
            }

            // 通过逗号找到key结束位置
            guard let keyEndIndex = rawKey.firstIndex(of: commaASCIICode) else {
                throw DecoderError.searchRawKeyFailed
            }

            // 通过原始key和key结束位置组装解码器
            try setCipher(keyBuffer: [UInt8]([UInt8](rawKey)[0..<keyEndIndex]))
        } else {
            // PC macOS端下载的文件
            let keySize = lastFourBytes.withUnsafeBytes {
                $0.load(as: UInt32.self).littleEndian
            }

            if keySize < 0x300 {
                // key 在固定位置
                self.realAudioSize = self.encryptedAudioLength - Int(keySize) - 4
                try fileHandle.seek(toOffset: UInt64(self.realAudioSize))
                guard let rawKey = try fileHandle.read(upToCount: Int(keySize)) else {
                    throw DecoderError.canNotReadRawKeyBuffer
                }

                try setCipher(keyBuffer: [UInt8](rawKey))
            } else {
                // 用固定key解码
                self.realAudioSize = self.encryptedAudioLength
                self.cipher = try QMStaticCipher(originKey: privateKey256)
            }
        }
    }

    func setCipher(keyBuffer: [UInt8]) throws {
        let keyDecoder = QMCKeyDecoder()
        let decodedKey = try keyDecoder.deriveKey(keyBuffer)

        if decodedKey.count > 300 {
            self.cipher = try QMRC4Cipher(originKey: decodedKey)
        } else {
            self.cipher = try QMMapCipher(originKey: decodedKey)
        }
    }

    private func uniqueOutputURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return url
        }

        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

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

    private func detectEncryptedAudioLength(fileHandle: FileHandle) throws -> Int {
        guard originFileLength >= 16 else {
            return originFileLength
        }

        try fileHandle.seek(toOffset: UInt64(originFileLength - 8))
        guard let tailMagic = try fileHandle.read(upToCount: 8),
              String(data: tailMagic, encoding: .utf8) == "musicex\0" else {
            return originFileLength
        }

        try fileHandle.seek(toOffset: UInt64(originFileLength - 16))
        guard let sizeData = try fileHandle.read(upToCount: 4), sizeData.count == 4 else {
            return originFileLength
        }

        let trailerSize = sizeData.withUnsafeBytes {
            Int($0.load(as: UInt32.self).littleEndian)
        }
        guard trailerSize > 0, trailerSize < originFileLength else {
            return originFileLength
        }

        return originFileLength - trailerSize
    }

    private func isValidAudioHeader(_ data: Data, fileExtension: String) -> Bool {
        let bytes = [UInt8](data.prefix(16))
        guard bytes.isEmpty == false else {
            return false
        }

        switch fileExtension {
        case "flac":
            return bytes.starts(with: Array("fLaC".utf8))
        case "ogg":
            return bytes.starts(with: Array("OggS".utf8))
        case "mp3":
            return bytes.starts(with: Array("ID3".utf8))
                || (bytes.count >= 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0)
        case "m4a":
            return bytes.count >= 12 && bytes[4...7].elementsEqual(Array("ftyp".utf8))
        case "wav":
            return bytes.starts(with: Array("RIFF".utf8))
        default:
            return true
        }
    }
}

extension QMDecoder.DecoderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportFileExtension(let ext):
            return L10n.tr("error.unsupportedExtension", ext)
        case .canNotReadFile:
            return L10n.tr("error.cannotReadFile")
        case .canNotReadFileByStream:
            return L10n.tr("error.cannotOpenStream")
        case .canNotGetFileLength:
            return L10n.tr("error.cannotGetLength")
        case .canNotReadSizeBuffer:
            return L10n.tr("error.cannotReadSize")
        case .canNotReadRawKeyBuffer:
            return L10n.tr("error.cannotReadRawKey")
        case .searchRawKeyFailed:
            return L10n.tr("error.searchRawKeyFailed")
        case .unsupportedEncryptedKey:
            return L10n.tr("error.unsupportedEncryptedKey")
        }
    }
}
