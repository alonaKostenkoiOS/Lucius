import Foundation

/// Generates scene images through AI Horde — a free, crowdsourced
/// generation network that works anonymously, without registration.
/// Used as a fallback on devices without Image Playground support.
///
/// The flow is asynchronous: submit a request, poll until a volunteer
/// worker finishes it, then download the resulting image.
struct ImageGenerationService {
    static let shared = ImageGenerationService()

    enum GenerationError: Error {
        case invalidPrompt
        case serviceBusy
        case offline
        case badResponse
    }

    private static let apiBase = "https://aihorde.net/api/v2"
    /// Documented anonymous key — lowest queue priority, but free.
    private static let anonymousAPIKey = "0000000000"

    /// A personal key from aihorde.net (set in Settings) gets a much
    /// higher queue priority than the anonymous one.
    private static var apiKey: String {
        let userKey = APIKeyStore.aiHordeKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return userKey.isEmpty ? anonymousAPIKey : userKey
    }
    private static let clientAgent = "Lucius:1.0:vocabulary-app"
    private static let pollInterval: Duration = .seconds(4)
    private static let maxWaitTime: TimeInterval = 240

    /// SDXL checkpoints with the most volunteer workers — far better
    /// quality than the default Stable Diffusion 1.5.
    private static let preferredModels = [
        "AlbedoBase XL 3.1",
        "AlbedoBase XL (SDXL)",
    ]

    /// AI Horde appends everything after `###` as the negative prompt.
    private static let negativePrompt =
        "blurry, lowres, ugly, deformed, distorted, watermark, text, signature, oversaturated"

    private init() {}

    /// Generates an image, reporting the queue's estimated wait (seconds)
    /// through `onProgress` while the request is being processed.
    func generateImage(prompt: String, onProgress: ((Int) -> Void)? = nil) async throws -> Data {
        let styledPrompt = "beautiful storybook illustration, dreamy soft pastel palette, "
            + "gentle lavender atmosphere, cozy detailed scene, soft warm lighting, "
            + "\(prompt) ### \(Self.negativePrompt)"

        do {
            let requestID = try await submitRequest(prompt: styledPrompt)
            try await waitUntilFinished(requestID: requestID, onProgress: onProgress)
            let imageURL = try await fetchResultURL(requestID: requestID)

            return try await downloadImage(from: imageURL)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw GenerationError.offline
        }
    }

    /// `URLError` codes that mean "no usable connection" rather than a server fault.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .dataNotAllowed,
    ]

    // MARK: - API key validation

    struct HordeUser: Decodable {
        let username: String
        let kudos: Double
    }

    /// Asks the Horde who owns the key — confirms the key is recognized
    /// and shows the kudos balance that drives queue priority.
    func validateAPIKey(_ key: String) async throws -> HordeUser {
        guard let url = URL(string: "\(Self.apiBase)/find_user") else {
            throw GenerationError.badResponse
        }

        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue(Self.clientAgent, forHTTPHeaderField: "Client-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GenerationError.badResponse
        }

        return try JSONDecoder().decode(HordeUser.self, from: data)
    }

    // MARK: - API steps

    private struct GenerationRequest: Encodable {
        struct Params: Encodable {
            let width: Int
            let height: Int
            let steps: Int
            let n: Int
            let cfgScale: Double
            let samplerName: String
            let karras: Bool

            enum CodingKeys: String, CodingKey {
                case width, height, steps, n, karras
                case cfgScale = "cfg_scale"
                case samplerName = "sampler_name"
            }
        }

        let prompt: String
        let params: Params
        let models: [String]
        let r2: Bool
    }

    private struct SubmitResponse: Decodable {
        let id: String
    }

    private struct CheckResponse: Decodable {
        let done: Bool
        let faulted: Bool
        let isPossible: Bool
        let waitTime: Int

        enum CodingKeys: String, CodingKey {
            case done
            case faulted
            case isPossible = "is_possible"
            case waitTime = "wait_time"
        }
    }

    private struct StatusResponse: Decodable {
        struct Generation: Decodable {
            let img: String
        }

        let generations: [Generation]
    }

    private func submitRequest(prompt: String) async throws -> String {
        guard let url = URL(string: "\(Self.apiBase)/generate/async") else {
            throw GenerationError.badResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.apiKey, forHTTPHeaderField: "apikey")
        request.setValue(Self.clientAgent, forHTTPHeaderField: "Client-Agent")
        request.httpBody = try JSONEncoder().encode(GenerationRequest(
            prompt: prompt,
            params: .init(
                width: 1024,
                height: 768,
                steps: 24,
                n: 1,
                cfgScale: 6,
                samplerName: "k_dpmpp_2m",
                karras: true
            ),
            models: Self.preferredModels,
            r2: true
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 429 || statusCode == 503 {
            throw GenerationError.serviceBusy
        }
        guard statusCode == 202 || statusCode == 200 else {
            throw GenerationError.badResponse
        }

        return try JSONDecoder().decode(SubmitResponse.self, from: data).id
    }

    private func waitUntilFinished(requestID: String, onProgress: ((Int) -> Void)?) async throws {
        let deadline = Date.now.addingTimeInterval(Self.maxWaitTime)

        while Date.now < deadline {
            guard let url = URL(string: "\(Self.apiBase)/generate/check/\(requestID)") else {
                throw GenerationError.badResponse
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let check = try JSONDecoder().decode(CheckResponse.self, from: data)

            if check.faulted || !check.isPossible {
                throw GenerationError.badResponse
            }
            if check.done {
                return
            }

            onProgress?(check.waitTime)
            try await Task.sleep(for: Self.pollInterval)
        }

        // No worker picked the request up in time.
        throw GenerationError.serviceBusy
    }

    private func fetchResultURL(requestID: String) async throws -> URL {
        guard let url = URL(string: "\(Self.apiBase)/generate/status/\(requestID)") else {
            throw GenerationError.badResponse
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let status = try JSONDecoder().decode(StatusResponse.self, from: data)

        guard let imageURLString = status.generations.first?.img,
              let imageURL = URL(string: imageURLString)
        else {
            throw GenerationError.badResponse
        }

        return imageURL
    }

    private func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw GenerationError.badResponse
        }

        return data
    }
}
