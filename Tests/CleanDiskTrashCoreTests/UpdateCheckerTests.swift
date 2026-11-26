import XCTest
@testable import CleanDiskTrashCore

final class UpdateCheckerTests: XCTestCase {
    func testReleaseKeyMatchesBundleIDConvention() {
        XCTAssertEqual(
            UpdateChecker.key(for: "com.cleandisktrash.app"),
            "633a445def67474255ed5b9897252510"
        )
    }

    func testNewerReleaseDecodesNotesAndTrustedDeduplicatedURLs() async throws {
        let json = #"""
            {
            "version":"1.1.0",
            "build":2,
            "notes":"改进扫描规则",
            "url":"https://gitee.com/lanshanshu/release/releases/download/key.2/key.zip",
            "urls":[
                "https://gitee.com/lanshanshu/release/releases/download/key.2/key.zip",
                "https://example.com/not-trusted.zip"
            ]
        }
        """#
        let checker = makeChecker(currentBuild: 1, data: Data(json.utf8))

        let release = try await checker.check()
        XCTAssertEqual(release?.version, "1.1.0")
        XCTAssertEqual(release?.notes, "改进扫描规则")
        XCTAssertEqual(release?.downloadURLs.count, 1)
        XCTAssertEqual(release?.downloadURLs.first?.host, "gitee.com")
    }

    func testCurrentOrOlderBuildIsNotAnUpdate() async throws {
        let checker = makeChecker(
            currentBuild: 2,
            data: Data(#"{"version":"1.1.0","build":2}"#.utf8)
        )
        let release = try await checker.check()
        XCTAssertNil(release)
    }

    func testUnpublishedManifestIsNormalNoUpdateState() async throws {
        let checker = makeChecker(currentBuild: 1, data: Data(), status: 404)
        let release = try await checker.check()
        XCTAssertNil(release)
    }

    func testNewBuildWithoutTrustedDownloadFails() async {
        let checker = makeChecker(
            currentBuild: 1,
            data: Data(#"{"version":"1.1.0","build":2,"url":"https://example.com/app.zip"}"#.utf8)
        )
        do {
            _ = try await checker.check()
            XCTFail("Expected missingDownload")
        } catch {
            XCTAssertEqual(error as? UpdateCheckError, .missingDownload)
        }
    }

    func testServerFailureIsReported() async {
        let checker = makeChecker(currentBuild: 1, data: Data(), status: 503)
        do {
            _ = try await checker.check()
            XCTFail("Expected serverStatus")
        } catch {
            XCTAssertEqual(error as? UpdateCheckError, .serverStatus(503))
        }
    }

    func testOversizedManifestIsRejected() async {
        let checker = makeChecker(currentBuild: 1, data: Data(repeating: 0x20, count: 65_537))
        do {
            _ = try await checker.check()
            XCTFail("Expected responseTooLarge")
        } catch {
            XCTAssertEqual(error as? UpdateCheckError, .responseTooLarge)
        }
    }

    private func makeChecker(
        currentBuild: Int,
        data: Data,
        status: Int = 200
    ) -> UpdateChecker {
        UpdateChecker(
            appID: "com.cleandisktrash.app",
            currentVersion: "1.0.0",
            currentBuild: currentBuild
        ) { _ in
            UpdateResponse(data: data, statusCode: status)
        }
    }
}
