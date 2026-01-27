import XCTest
@testable import MoovIt

final class FastStartConverterTests: XCTestCase {

    var testFilesURL: URL!
    var tempDirectory: URL!

    override func setUpWithError() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        testFilesURL = projectDir.appendingPathComponent("TestFiles")

        // Create temp directory for output files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoovItTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - MP4 Conversion Tests

    func testMP4Conversion() throws {
        let inputURL = testFilesURL.appendingPathComponent("test_not_optimized.mp4")
        let outputURL = tempDirectory.appendingPathComponent("converted.mp4")

        // Verify input needs conversion
        let beforeAnalysis = try MP4Parser.analyze(url: inputURL)
        XCTAssertFalse(beforeAnalysis.isFastStart, "Input should not be fast-start")

        // Convert
        try FastStartConverter.convert(input: inputURL, output: outputURL)

        // Verify output is optimized
        let afterAnalysis = try MP4Parser.analyze(url: outputURL)
        XCTAssertTrue(afterAnalysis.isFastStart, "Output should be fast-start")
    }

    // MARK: - MOV Conversion Tests

    func testMOVConversion() throws {
        let inputURL = testFilesURL.appendingPathComponent("test.mov")
        let outputURL = tempDirectory.appendingPathComponent("converted.mov")

        try FastStartConverter.convert(input: inputURL, output: outputURL)

        let afterAnalysis = try MP4Parser.analyze(url: outputURL)
        XCTAssertTrue(afterAnalysis.isFastStart, "Converted MOV should be fast-start")
    }

    // MARK: - M4V Conversion Tests

    func testM4VConversion() throws {
        let inputURL = testFilesURL.appendingPathComponent("test.m4v")
        let outputURL = tempDirectory.appendingPathComponent("converted.m4v")

        try FastStartConverter.convert(input: inputURL, output: outputURL)

        let afterAnalysis = try MP4Parser.analyze(url: outputURL)
        XCTAssertTrue(afterAnalysis.isFastStart, "Converted M4V should be fast-start")
    }

    // MARK: - M4A Conversion Tests

    func testM4AConversion() throws {
        let inputURL = testFilesURL.appendingPathComponent("test.m4a")
        let outputURL = tempDirectory.appendingPathComponent("converted.m4a")

        try FastStartConverter.convert(input: inputURL, output: outputURL)

        let afterAnalysis = try MP4Parser.analyze(url: outputURL)
        XCTAssertTrue(afterAnalysis.isFastStart, "Converted M4A should be fast-start")
    }

    // MARK: - 3GP Conversion Tests

    func test3GPConversion() throws {
        let inputURL = testFilesURL.appendingPathComponent("test.3gp")
        let outputURL = tempDirectory.appendingPathComponent("converted.3gp")

        try FastStartConverter.convert(input: inputURL, output: outputURL)

        let afterAnalysis = try MP4Parser.analyze(url: outputURL)
        XCTAssertTrue(afterAnalysis.isFastStart, "Converted 3GP should be fast-start")
    }

    // MARK: - Already Optimized Tests

    func testAlreadyOptimizedThrows() throws {
        let inputURL = testFilesURL.appendingPathComponent("test_optimized.mp4")
        let outputURL = tempDirectory.appendingPathComponent("should_not_exist.mp4")

        XCTAssertThrowsError(try FastStartConverter.convert(input: inputURL, output: outputURL)) { error in
            // Should throw invalidAtomStructure because moov is already before mdat
        }
    }

    // MARK: - File Integrity Tests

    func testConvertedFileSize() throws {
        let inputURL = testFilesURL.appendingPathComponent("test_not_optimized.mp4")
        let outputURL = tempDirectory.appendingPathComponent("converted.mp4")

        let inputSize = try FileManager.default.attributesOfItem(atPath: inputURL.path)[.size] as! Int64

        try FastStartConverter.convert(input: inputURL, output: outputURL)

        let outputSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as! Int64

        // Output should be similar size (may be slightly smaller due to removed free atoms)
        let sizeDiff = abs(inputSize - outputSize)
        XCTAssertLessThan(sizeDiff, 10000, "File size should be similar after conversion")
    }

    // MARK: - Free Atom Removal Tests

    func testRemoveFreeAtomsFromOptimizedFile() throws {
        let inputURL = testFilesURL.appendingPathComponent("test_optimized.mp4")
        let outputURL = tempDirectory.appendingPathComponent("no_free.mp4")

        // Verify input has free atoms
        let beforeAnalysis = try MP4Parser.analyze(url: inputURL)
        guard beforeAnalysis.hasFreeAtom else {
            // Skip test if no free atoms
            return
        }

        // Convert with free atom removal only
        try FastStartConverter.convert(input: inputURL, output: outputURL, options: .removeFreeOnly)

        // Verify output has no free atoms
        let afterAnalysis = try MP4Parser.analyze(url: outputURL)
        XCTAssertFalse(afterAnalysis.hasFreeAtom, "Output should not have free atoms")
        XCTAssertTrue(afterAnalysis.isFastStart, "Output should still be fast-start")
    }

    func testConversionOptions() throws {
        let inputURL = testFilesURL.appendingPathComponent("test_not_optimized.mp4")

        // Test with default options (both enabled)
        let output1 = tempDirectory.appendingPathComponent("default.mp4")
        try FastStartConverter.convert(input: inputURL, output: output1, options: .default)
        let analysis1 = try MP4Parser.analyze(url: output1)
        XCTAssertTrue(analysis1.isFastStart)
        XCTAssertFalse(analysis1.hasFreeAtom)

        // Test with fast-start only
        let output2 = tempDirectory.appendingPathComponent("faststart_only.mp4")
        try FastStartConverter.convert(input: inputURL, output: output2, options: .fastStartOnly)
        let analysis2 = try MP4Parser.analyze(url: output2)
        XCTAssertTrue(analysis2.isFastStart)
    }

    func testNothingToOptimizeThrows() throws {
        // First create a fully optimized file
        let inputURL = testFilesURL.appendingPathComponent("test_not_optimized.mp4")
        let optimizedURL = tempDirectory.appendingPathComponent("optimized.mp4")
        try FastStartConverter.convert(input: inputURL, output: optimizedURL, options: .default)

        // Now try to optimize it again
        let outputURL = tempDirectory.appendingPathComponent("should_fail.mp4")
        XCTAssertThrowsError(try FastStartConverter.convert(input: optimizedURL, output: outputURL, options: .default)) { error in
            // Should throw nothingToOptimize error
        }
    }
}
