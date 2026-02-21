import Foundation

enum DeepgramError: LocalizedError {
    case fileNotFound
    case invalidResponse
    case apiError(Int, String)
    case parseError
    case emptyTranscript
    case timeout
    case network(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .invalidResponse:
            return "Invalid response from Deepgram"
        case .apiError(let code, let message):
            return "Deepgram API error \(code): \(message)"
        case .parseError:
            return "Failed to parse Deepgram response"
        case .emptyTranscript:
            return "No speech detected"
        case .timeout:
            return "Deepgram request timed out"
        case .network(let message):
            return "Network error: \(message)"
        }
    }
}

private struct DeepgramResponse: Decodable {
    struct Results: Decodable {
        struct Channel: Decodable {
            struct Alternative: Decodable {
                let transcript: String
            }

            let alternatives: [Alternative]
        }

        let channels: [Channel]
    }

    let results: Results
}

final class DeepgramTranscriptionService {
    static let shared = DeepgramTranscriptionService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 35
        self.session = URLSession(configuration: config)
    }

    func transcribe(fileURL: URL, apiKey: String, language: String?) async throws -> String {
        guard let audioData = try? Data(contentsOf: fileURL) else {
            throw DeepgramError.fileNotFound
        }

        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")
        var queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true")
        ]
        if let language, !language.isEmpty {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw DeepgramError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = audioData
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType(for: fileURL), forHTTPHeaderField: "Content-Type")

        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw DeepgramError.invalidResponse
                }

                if (httpResponse.statusCode == 408 || (500...599).contains(httpResponse.statusCode)) && attempt == 0 {
                    try await Task.sleep(nanoseconds: 350_000_000)
                    continue
                }

                guard httpResponse.statusCode == 200 else {
                    let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw DeepgramError.apiError(httpResponse.statusCode, body)
                }

                guard let decoded = try? JSONDecoder().decode(DeepgramResponse.self, from: data) else {
                    throw DeepgramError.parseError
                }

                let transcript = decoded.results.channels
                    .first?.alternatives.first?.transcript
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard !transcript.isEmpty else {
                    throw DeepgramError.emptyTranscript
                }

                return transcript
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError {
                lastError = error
                if shouldRetry(urlError: error, attempt: attempt) {
                    try await Task.sleep(nanoseconds: 350_000_000)
                    continue
                }
                throw mapNetworkError(error)
            } catch let error as DeepgramError {
                lastError = error
                if shouldRetry(deepgramError: error, attempt: attempt) {
                    try await Task.sleep(nanoseconds: 350_000_000)
                    continue
                }
                throw error
            } catch {
                lastError = error
                throw error
            }
        }

        if let networkError = lastError as? URLError {
            throw mapNetworkError(networkError)
        }
        throw lastError ?? DeepgramError.invalidResponse
    }

    private func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "m4a": return "audio/m4a"
        case "mp4": return "audio/mp4"
        case "aac": return "audio/aac"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "ogg", "opus": return "audio/ogg"
        default: return "application/octet-stream"
        }
    }

    private func shouldRetry(urlError: URLError, attempt: Int) -> Bool {
        guard attempt == 0 else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    private func shouldRetry(deepgramError: DeepgramError, attempt: Int) -> Bool {
        guard attempt == 0 else { return false }
        switch deepgramError {
        case .timeout, .network:
            return true
        case .apiError(let code, _):
            return code == 408 || code == 429 || (500...599).contains(code)
        case .fileNotFound, .invalidResponse, .parseError, .emptyTranscript:
            return false
        }
    }

    private func mapNetworkError(_ error: URLError) -> DeepgramError {
        if error.code == .timedOut {
            return .timeout
        }
        return .network(error.localizedDescription)
    }
}
