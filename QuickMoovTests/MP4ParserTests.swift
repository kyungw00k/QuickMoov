import XCTest
@testable import QuickMoov

final class MP4ParserTests: XCTestCase {

    var testFilesURL: URL!

    override func setUpWithError() throws {
        // Get TestFiles directory path
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        testFilesURL = projectDir.appendingPathComponent("TestFiles")
    }

    // MARK: - MP4 Tests

    func testMP4NotOptimized() throws {
        let url = testFilesURL.appendingPathComponent("test_not_optimized.mp4")
        let analysis = try MP4Parser.analyze(url: url)

        XCTAssertFalse(analysis.isFastStart, "Non-optimized MP4 should not have fast-start")
        XCTAssertTrue(analysis.atoms.contains("moov"), "Should contain moov atom")
        XCTAssertTrue(analysis.atoms.contains("mdat"), "Should contain mdat atom")
    }

    func testMP4Optimized() throws {
        let url = testFilesURL.appendingPathComponent("test_optimized.mp4")
        let analysis = try MP4Parser.analyze(url: url)

        XCTAssertTrue(analysis.isFastStart, "Optimized MP4 should have fast-start")
    }

    // MARK: - MOV Tests

    func testMOVParsing() throws {
        let url = testFilesURL.appendingPathComponent("test.mov")
        let analysis = try MP4Parser.analyze(url: url)

        XCTAssertFalse(analysis.isFastStart, "Default MOV should not have fast-start")
        XCTAssertTrue(analysis.atoms.contains("moov"), "Should contain moov atom")
        XCTAssertTrue(analysis.atoms.contains("mdat"), "Should contain mdat atom")
    }

    // MARK: - M4V Tests

    func testM4VParsing() throws {
        let url = testFilesURL.appendingPathComponent("test.m4v")
        let analysis = try MP4Parser.analyze(url: url)

        XCTAssertFalse(analysis.isFastStart, "Default M4V should not have fast-start")
        XCTAssertTrue(analysis.atoms.contains("moov"), "Should contain moov atom")
    }

    // MARK: - M4A Tests

    func testM4AParsing() throws {
        let url = testFilesURL.appendingPathComponent("test.m4a")
        let analysis = try MP4Parser.analyze(url: url)

        XCTAssertFalse(analysis.isFastStart, "Default M4A should not have fast-start")
        XCTAssertTrue(analysis.atoms.contains("moov"), "Should contain moov atom")
    }

    // MARK: - 3GP Tests

    func test3GPParsing() throws {
        let url = testFilesURL.appendingPathComponent("test.3gp")
        let analysis = try MP4Parser.analyze(url: url)

        XCTAssertFalse(analysis.isFastStart, "Default 3GP should not have fast-start")
        XCTAssertTrue(analysis.atoms.contains("moov"), "Should contain moov atom")
    }

    // MARK: - Atom Parsing Tests

    func testAtomParsing() throws {
        let url = testFilesURL.appendingPathComponent("test_not_optimized.mp4")
        let atoms = try MP4Parser.parseAtoms(url: url)

        XCTAssertGreaterThan(atoms.count, 0, "Should parse at least one atom")
        XCTAssertEqual(atoms.first?.type, "ftyp", "First atom should be ftyp")
    }

    func testFindAtom() throws {
        let url = testFilesURL.appendingPathComponent("test_not_optimized.mp4")
        let atoms = try MP4Parser.parseAtoms(url: url)

        let moov = MP4Parser.findAtom("moov", in: atoms)
        XCTAssertNotNil(moov, "Should find moov atom")

        let nonexistent = MP4Parser.findAtom("xxxx", in: atoms)
        XCTAssertNil(nonexistent, "Should not find nonexistent atom")
    }

    // MARK: - Error Handling Tests

    func testFileNotFound() {
        let url = testFilesURL.appendingPathComponent("nonexistent.mp4")

        XCTAssertThrowsError(try MP4Parser.analyze(url: url)) { error in
            // Should throw file not found error
        }
    }
}
