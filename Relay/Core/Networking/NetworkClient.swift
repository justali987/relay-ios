import Foundation

/// Thin async wrapper around `URLSession` adding a bounded timeout and exponential-backoff retry.
/// Every real adapter (Roku, webOS, Tizen, ...) should route its LAN requests through this, rather
/// than calling `URLSession` directly, so retry/backoff behavior is consistent across protocols.
struct NetworkClient: Sendable {
    var session: URLSession = .shared
    var maxAttempts: Int = 3
    var baseBackoffSeconds: Double = 0.4
    var timeoutSeconds: Double = 5

    enum ClientError: Error, Equatable {
        case timedOut
        case httpStatus(Int)
        case transport(String)
    }

    /// Performs a request, retrying transient failures (timeouts, 5xx) with exponential backoff.
    /// Does not retry 4xx responses — those indicate the request itself is wrong, not the network.
    func send(_ request: URLRequest) async throws -> Data {
        var attempt = 0
        var lastError: Error = ClientError.timedOut

        while attempt < maxAttempts {
            attempt += 1
            var attemptRequest = request
            attemptRequest.timeoutInterval = timeoutSeconds

            do {
                let (data, response) = try await session.data(for: attemptRequest)
                guard let http = response as? HTTPURLResponse else {
                    return data
                }
                if (200..<300).contains(http.statusCode) {
                    return data
                }
                if (400..<500).contains(http.statusCode) {
                    throw ClientError.httpStatus(http.statusCode)
                }
                lastError = ClientError.httpStatus(http.statusCode)
            } catch let error as ClientError {
                throw error
            } catch {
                lastError = ClientError.transport(error.localizedDescription)
            }

            if attempt < maxAttempts {
                let backoff = baseBackoffSeconds * pow(2, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
        }

        throw lastError
    }
}
