import XCTest
@testable import Relay

final class NetworkClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NetworkSimulator.reset()
    }

    private func makeClient() -> NetworkClient {
        NetworkClient(session: NetworkSimulator.makeSession(), maxAttempts: 3, baseBackoffSeconds: 0.01, timeoutSeconds: 1)
    }

    func testSuccessfulResponseReturnsData() async throws {
        let expected = "hello".data(using: .utf8)!
        NetworkSimulator.scriptedResponses = [.success(statusCode: 200, body: expected)]

        let data = try await makeClient().send(URLRequest(url: URL(string: "http://10.0.0.1:8060/query/device-info")!))
        XCTAssertEqual(data, expected)
    }

    func test5xxRetriesThenSucceeds() async throws {
        let expected = "recovered".data(using: .utf8)!
        NetworkSimulator.scriptedResponses = [
            .success(statusCode: 503, body: Data()),
            .success(statusCode: 503, body: Data()),
            .success(statusCode: 200, body: expected),
        ]

        let data = try await makeClient().send(URLRequest(url: URL(string: "http://10.0.0.1:8060/query/device-info")!))
        XCTAssertEqual(data, expected)
    }

    func test4xxDoesNotRetry() async throws {
        NetworkSimulator.scriptedResponses = [
            .success(statusCode: 404, body: Data()),
            .success(statusCode: 200, body: Data("should-not-be-reached".utf8)),
        ]

        do {
            _ = try await makeClient().send(URLRequest(url: URL(string: "http://10.0.0.1:8060/query/device-info")!))
            XCTFail("Expected a thrown error for a 404")
        } catch NetworkClient.ClientError.httpStatus(let code) {
            XCTAssertEqual(code, 404)
        }
    }

    func testTransportErrorExhaustsRetriesAndThrows() async throws {
        NetworkSimulator.scriptedResponses = [
            .transportError(), .transportError(), .transportError(),
        ]

        do {
            _ = try await makeClient().send(URLRequest(url: URL(string: "http://10.0.0.1:8060/query/device-info")!))
            XCTFail("Expected a thrown error after exhausting retries")
        } catch {
            // any thrown error is acceptable here — the point is that it doesn't hang or succeed
        }
    }
}
