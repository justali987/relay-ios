import Foundation
import Network

/// SSDP (Simple Service Discovery Protocol) multicast search, used by Roku's External Control
/// Protocol (and many other UPnP-ish devices) for discovery — distinct from the Bonjour/mDNS
/// discovery `BonjourDiscoveryService` handles for Android TV. Sends an M-SEARCH datagram to
/// 239.255.255.250:1900 and yields raw `LOCATION` header values as responses arrive.
///
/// Reference: Roku ECP discovery — https://developer.roku.com/docs/developer-program/debugging/external-control-api.md#discovering-roku-devices
final class SSDPDiscoveryService: @unchecked Sendable {
    private var connection: NWConnection?

    struct SSDPResponse: Sendable {
        let locationURL: String
        let searchTarget: String
    }

    /// Sends one M-SEARCH request for the given search target (e.g. "roku:ecp") and yields each
    /// distinct response as it arrives. The stream does not finish on its own — the caller (an
    /// adapter's `discover()`) owns how long to keep listening.
    func search(searchTarget: String, timeout: TimeInterval = 4) -> AsyncStream<SSDPResponse> {
        AsyncStream { continuation in
            let params = NWParameters.udp
            let host = NWEndpoint.Host("239.255.255.250")
            let port = NWEndpoint.Port(1900)
            let connection = NWConnection(host: host, port: port, using: params)
            self.connection = connection

            let message = [
                "M-SEARCH * HTTP/1.1",
                "HOST: 239.255.255.250:1900",
                "MAN: \"ssdp:discover\"",
                "MX: 2",
                "ST: \(searchTarget)",
                "", "",
            ].joined(separator: "\r\n")

            connection.stateUpdateHandler = { state in
                guard case .ready = state else { return }
                connection.send(content: message.data(using: .utf8), completion: .contentProcessed { _ in
                    self.receiveLoop(on: connection, searchTarget: searchTarget, continuation: continuation)
                })
            }

            connection.start(queue: .global(qos: .utility))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                connection.cancel()
                continuation.finish()
            }

            continuation.onTermination = { _ in connection.cancel() }
        }
    }

    private func receiveLoop(
        on connection: NWConnection,
        searchTarget: String,
        continuation: AsyncStream<SSDPResponse>.Continuation
    ) {
        connection.receiveMessage { data, _, _, error in
            defer {
                if error == nil {
                    self.receiveLoop(on: connection, searchTarget: searchTarget, continuation: continuation)
                }
            }
            guard let data, let text = String(data: data, encoding: .utf8) else { return }
            guard let location = Self.parseHeader("LOCATION", from: text) else { return }
            continuation.yield(SSDPResponse(locationURL: location, searchTarget: searchTarget))
        }
    }

    private static func parseHeader(_ name: String, from response: String) -> String? {
        for line in response.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].caseInsensitiveCompare(name) == .orderedSame else { continue }
            return parts[1].trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    func stop() {
        connection?.cancel()
    }
}
