import Foundation

/// Outcome of a single POST to the `/track` endpoint.
enum HttpOutcome {
  case success
  /// 4xx other than 429 — the event itself is invalid, retrying is futile.
  case clientError(code: Int)
  /// Network error, 5xx or 429 — retry with backoff.
  case retryable(code: Int?, error: Error?)
}

/// Minimal HTTP POST on top of URLSession — zero dependencies.
///
/// Blocking on purpose: it is called only from the SDK serial queue, which
/// naturally serializes request traffic.
enum HttpPoster {
  private static let timeout: TimeInterval = 10

  static func post(url: String, headers: [String: String], body: [String: Any]) -> HttpOutcome {
    guard let requestUrl = URL(string: url) else {
      return .retryable(code: nil, error: nil)
    }
    var request = URLRequest(url: requestUrl)
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
    guard let data = try? JSONSerialization.data(withJSONObject: body) else {
      return .clientError(code: -1)
    }
    request.httpBody = data

    var outcome: HttpOutcome = .retryable(code: nil, error: nil)
    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { _, response, error in
      if let error {
        outcome = .retryable(code: nil, error: error)
      } else if let http = response as? HTTPURLResponse {
        switch http.statusCode {
        case 200...299: outcome = .success
        case 400...499 where http.statusCode != 429: outcome = .clientError(code: http.statusCode)
        default: outcome = .retryable(code: http.statusCode, error: nil)
        }
      } else {
        outcome = .retryable(code: nil, error: nil)
      }
      semaphore.signal()
    }.resume()
    semaphore.wait()
    return outcome
  }
}
