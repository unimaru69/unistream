import Foundation

extension URLSession {
    /// Fetch data with exponential backoff retry — mirrors Flutter's retry logic.
    func dataWithRetry(
        for request: URLRequest,
        maxRetries: Int = Constants.maxRetries
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode >= 500 {
                    throw URLError(.badServerResponse)
                }
                return (data, response)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    // Exponential backoff with jitter: min(1s * 2^attempt + jitter, 10s)
                    let base = pow(2.0, Double(attempt))
                    let jitter = Double.random(in: 0...0.5)
                    let delay = min(base + jitter, 10.0)
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}
