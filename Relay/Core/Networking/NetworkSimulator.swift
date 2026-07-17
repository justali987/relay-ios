import Foundation

/// A `URLProtocol` stub used only by `RelayTests` to inject latency, disconnects, and malformed
/// responses in front of `NetworkClient`, so retry/backoff behavior can be verified without a real
/// network or real device. Not linked into the shipping app target.
final class NetworkSimulator: URLProtocol, @unchecked Sendable {
    /// One scripted response per call, consumed in order. Configure this from a test before
    /// constructing the `URLSession` that uses this protocol.
    nonisolated(unsafe) static var scriptedResponses: [SimulatedResponse] = []
    nonisolated(unsafe) private static var callIndex = 0

    enum SimulatedResponse {
        case success(statusCode: Int, body: Data, delayMillis: Int = 0)
        case malformed(delayMillis: Int = 0)
        case transportError(delayMillis: Int = 0)
    }

    static func reset() {
        scriptedResponses = []
        callIndex = 0
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NetworkSimulator.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let index = Self.callIndex
        Self.callIndex += 1

        let response = index < Self.scriptedResponses.count
            ? Self.scriptedResponses[index]
            : .success(statusCode: 200, body: Data())

        let delay: Int
        switch response {
        case .success(_, _, let delayMillis): delay = delayMillis
        case .malformed(let delayMillis): delay = delayMillis
        case .transportError(let delayMillis): delay = delayMillis
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            guard let self, let client = self.client else { return }

            switch response {
            case .success(let statusCode, let body, _):
                let httpResponse = HTTPURLResponse(
                    url: self.request.url!,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                client.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self, didLoad: body)
                client.urlProtocolDidFinishLoading(self)

            case .malformed:
                let httpResponse = HTTPURLResponse(
                    url: self.request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                client.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self, didLoad: Data([0xFF, 0x00, 0xDE, 0xAD]))
                client.urlProtocolDidFinishLoading(self)

            case .transportError:
                client.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            }
        }
    }

    override func stopLoading() {}
}
