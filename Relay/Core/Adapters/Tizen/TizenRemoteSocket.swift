import Foundation

/// One live WebSocket connection to a Samsung Tizen TV's remote-control channel.
///
/// Protocol (Samsung "Multiscreen"/`ms.remote.control`): the phone opens a WebSocket to
/// `wss://<host>:8002/api/v2/channels/samsung.remote.control?name=<base64 name>`. On the FIRST
/// connection from a new client the TV shows an on-screen "Allow this device?" prompt; when the user
/// accepts, the TV sends an `ms.channel.connect` event whose `data.token` is a credential that skips
/// the prompt on every future connection. We persist that token (Keychain, via the adapter) and pass
/// it back as `&token=<token>`. A denial arrives as `ms.channel.unauthorized`.
///
/// Why 8002/`wss` first: 2018-and-later Tizen models only expose the secure port, with a self-signed
/// certificate — hence `InsecureTrustDelegate`, which trusts the LAN TV's cert (there is no CA to
/// validate a TV's rotating self-signed cert against, and the connection never leaves the local
/// network). 2016–2017 models are reachable on `ws://<host>:8001`; the adapter falls back to that.
///
/// Not `Sendable`: an instance is confined to `TizenAdapter`, which serialises access to it under a
/// lock. Reference: the community-documented samsungtvws protocol.
final class TizenRemoteSocket: NSObject, URLSessionWebSocketTaskDelegate {
    private let host: String
    private let useTLS: Bool
    private let token: String?

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?

    /// Result of a connection attempt: whether the TV accepted us and the (possibly refreshed) token.
    struct ConnectResult {
        let token: String?
    }

    init(host: String, useTLS: Bool, token: String?) {
        self.host = host
        self.useTLS = useTLS
        self.token = token
        super.init()
    }

    /// The remote-control channel URL. `name` is a human label the TV shows in its device list; the
    /// protocol requires it base64-encoded.
    private var channelURL: URL? {
        let scheme = useTLS ? "wss" : "ws"
        let port = useTLS ? 8002 : 8001
        let name = Data("Relay".utf8).base64EncodedString()
        var string = "\(scheme)://\(host):\(port)/api/v2/channels/samsung.remote.control?name=\(name)"
        if let token, !token.isEmpty {
            string += "&token=\(token)"
        }
        return URL(string: string)
    }

    /// Opens the socket and waits for the TV's authorisation decision.
    ///
    /// - With a valid `token` this resolves near-instantly (no on-screen prompt).
    /// - Without a token the TV shows its "Allow?" prompt and this waits up to `timeout` for the user
    ///   to walk over and accept — hence the deliberately long default.
    ///
    /// Throws `.pairingRejected` if the user denies, `.timeout` if no decision arrives, or
    /// `.unreachable` if the socket can't be opened at all.
    func connectAndAwaitAuthorization(timeout: TimeInterval = 30) async throws -> ConnectResult {
        guard let url = channelURL else { throw AdapterError.malformedResponse }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout + 5
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.task = task
        task.resume()

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                throw AdapterError.unreachable
            }

            guard let text = Self.text(from: message),
                  let event = Self.jsonObject(from: text) else { continue }

            switch event["event"] as? String {
            case "ms.channel.connect":
                // Accepted. A token is present on first approval and echoed back thereafter; some
                // firmware nests it under `data`.
                let data = event["data"] as? [String: Any]
                return ConnectResult(token: data?["token"] as? String ?? token)
            case "ms.channel.unauthorized":
                throw AdapterError.pairingRejected(
                    reason: "The TV declined the connection. On the TV, choose Allow when Relay asks to connect."
                )
            case "ms.channel.timeOut":
                throw AdapterError.timeout
            default:
                continue // ms.channel.clientConnect and keep-alives — keep waiting for a decision.
            }
        }
        throw AdapterError.timeout
    }

    /// Sends one remote key (e.g. `KEY_VOLUP`). The socket must already be authorised.
    func sendKey(_ key: String) async throws {
        guard let task else { throw AdapterError.notPaired }
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": key,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey",
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else {
            throw AdapterError.malformedResponse
        }
        do {
            try await task.send(.string(string))
        } catch {
            throw AdapterError.unreachable
        }
    }

    func close() {
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        task = nil
        session = nil
    }

    private static func text(from message: URLSessionWebSocketTask.Message) -> String? {
        switch message {
        case .string(let string): return string
        case .data(let data): return String(data: data, encoding: .utf8)
        @unknown default: return nil
        }
    }

    private static func jsonObject(from text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    // MARK: - URLSessionDelegate (self-signed LAN certificate trust)

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Tizen TVs present a self-signed certificate on :8002. There is no certificate authority to
        // validate a per-TV self-signed cert against, and the connection is confined to the local
        // network, so we accept the presented server trust. This is scoped to this ephemeral session,
        // which only ever connects to this one TV host.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
