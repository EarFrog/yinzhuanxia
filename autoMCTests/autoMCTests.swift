import XCTest
@testable import autoMC

final class autoMCTests: XCTestCase {
    func testSupportedExtensionsAreMappedToOutputFormats() {
        XCTAssertEqual(encryptExtDictionary["mflac"]?.ext, "flac")
        XCTAssertEqual(encryptExtDictionary["mgg"]?.ext, "ogg")
        XCTAssertEqual(encryptExtDictionary["qmc0"]?.ext, "mp3")
    }

    func testPlainAudioExtensionsAreSupportedInputs() {
        XCTAssertTrue(supportedInputExtensions.contains("mp3"))
        XCTAssertTrue(supportedInputExtensions.contains("flac"))
        XCTAssertTrue(supportedInputExtensions.contains("m4a"))
        XCTAssertTrue(supportedInputExtensions.contains("wav"))
    }

    func testOutputFormatRawValuesAreStable() {
        XCTAssertEqual(OutputFormat.mp3.rawValue, "mp3")
        XCTAssertEqual(OutputFormat.flac.rawValue, "flac")
        XCTAssertEqual(OutputFormat.original.rawValue, "original")
    }

    func testAudioFormatBreakdownGroupsSupportedExtensions() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.mp3"),
            URL(fileURLWithPath: "/tmp/b.flac"),
            URL(fileURLWithPath: "/tmp/c.mflac"),
            URL(fileURLWithPath: "/tmp/d.aiff"),
            URL(fileURLWithPath: "/tmp/e.aif")
        ]

        let breakdown = audioFormatBreakdownText(for: urls)
        XCTAssertTrue(breakdown.contains("MP3 1"))
        XCTAssertTrue(breakdown.contains("FLAC 1"))
        XCTAssertTrue(breakdown.contains("MFLAC->FLAC 1"))
        XCTAssertTrue(breakdown.contains("AIFF 2"))
    }

    func testStaticCipherRejectsEmptyKey() {
        XCTAssertThrowsError(try QMStaticCipher(originKey: []))
    }
}
