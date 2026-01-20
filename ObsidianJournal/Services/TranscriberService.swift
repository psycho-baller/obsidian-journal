import Foundation
import os
import WhisperKit
import Combine

protocol TranscriberServiceProtocol {
    func transcribe(audioURL: URL) async throws -> String
}

class TranscriberService: ObservableObject, TranscriberServiceProtocol {
    @Published var isTranscribing = false
    @Published var modelLoadingState: ModelLoadingState = .notLoaded
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading = false

    private var whisperPipe: WhisperKit?
    private var currentModelName: String?
    private var cancellables = Set<AnyCancellable>()

    enum ModelLoadingState: Equatable {
        case notLoaded
        case loading
        case downloading
        case loaded
        case error(String)
    }

    init() {
        // Subscribe to model changes
        TranscriptionSettings.shared.$selectedModel
            .sink { [weak self] model in
                guard let self = self else { return }
                Task {
                    await self.handleModelChange(model)
                }
            }
            .store(in: &cancellables)

        // Load initial model
        Task {
            await loadCurrentModel()
        }
    }

    @MainActor
    private func handleModelChange(_ model: TranscriptionModel) async {
        // Skip if cloud model selected or same model
        if model.isCloud {
            Logger.transcription.info("Switched to cloud transcription mode")
            whisperPipe = nil
            currentModelName = nil
            modelLoadingState = .notLoaded
            return
        }

        // If switching to a different local model
        if currentModelName != model.rawValue {
            await loadModel(named: model.rawValue)
        }
    }

    @MainActor
    func loadCurrentModel() async {
        let selectedModel = TranscriptionSettings.shared.selectedModel
        if selectedModel.isCloud {
            Logger.transcription.info("Cloud mode selected, skipping local model load")
            return
        }
        await loadModel(named: selectedModel.rawValue)
    }

    @MainActor
    func loadModel(named modelName: String) async {
        guard modelLoadingState != .loading && modelLoadingState != .downloading else { return }

        modelLoadingState = .loading
        Logger.transcription.info("Initializing WhisperKit with model: \(modelName)")

        do {
            // WhisperKit will automatically download (if needed) and load the model
            // optimizing for the Neural Engine where possible.
            whisperPipe = try await WhisperKit(model: modelName)
            currentModelName = modelName
            modelLoadingState = .loaded
            Logger.transcription.notice("WhisperKit initialized successfully with model: \(modelName)")
        } catch {
            Logger.transcription.error("Failed to load WhisperKit: \(error.localizedDescription)")
            modelLoadingState = .error(error.localizedDescription)
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        let selectedModel = TranscriptionSettings.shared.selectedModel

        // Route to cloud or local transcription
        if selectedModel.isCloud {
            return try await transcribeCloud(audioURL: audioURL)
        } else {
            return try await transcribeLocal(audioURL: audioURL)
        }
    }

    // MARK: - Local Transcription (WhisperKit)

    private func transcribeLocal(audioURL: URL) async throws -> String {
        guard let pipe = whisperPipe else {
            if modelLoadingState == .notLoaded || modelLoadingState == .loading {
                Logger.transcription.warning("Transcription requested but model not ready. Waiting...")
                await loadCurrentModel()
                // Check again
                guard let pipe = whisperPipe else {
                    throw TranscriberError.modelNotInitialized
                }
                return try await performTranscription(pipe: pipe, url: audioURL)
            }
            throw TranscriberError.modelNotInitialized
        }

        return try await performTranscription(pipe: pipe, url: audioURL)
    }

    private func performTranscription(pipe: WhisperKit, url: URL) async throws -> String {
        Logger.transcription.info("Starting transcription for file: \(url.lastPathComponent)")

        await MainActor.run { self.isTranscribing = true }
        defer { Task { @MainActor in self.isTranscribing = false } }

        do {
            // Transcribe
            let results = try await pipe.transcribe(audioPath: url.path)

            Logger.transcription.debug("Raw segments count: \(results.count)")
            for (i, segment) in results.enumerated() {
                Logger.transcription.debug("Segment \(i): \(segment.text)")
            }

            // Combine segments
            let fullText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            Logger.transcription.notice("Transcription completed. Length: \(fullText.count)")
            return fullText

        } catch {
            Logger.transcription.error("Transcription failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Cloud Transcription (OpenAI Whisper API)

    private func transcribeCloud(audioURL: URL) async throws -> String {
        Logger.transcription.info("Starting cloud transcription via OpenAI")

        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            throw TranscriberError.missingAPIKey
        }

        await MainActor.run { self.isTranscribing = true }
        defer { Task { @MainActor in self.isTranscribing = false } }

        // Read audio file
        let audioData = try Data(contentsOf: audioURL)

        // Create multipart form request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        Logger.transcription.debug("Sending audio to OpenAI Whisper API...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriberError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.transcription.error("OpenAI API error: \(httpResponse.statusCode) - \(errorBody)")
            throw TranscriberError.networkError("API error: \(httpResponse.statusCode)")
        }

        // Parse response
        struct WhisperResponse: Decodable {
            let text: String
        }

        let decoded = try JSONDecoder().decode(WhisperResponse.self, from: data)
        Logger.transcription.notice("Cloud transcription completed. Length: \(decoded.text.count)")

        return decoded.text
    }
}

enum TranscriberError: Error, LocalizedError {
    case modelNotInitialized
    case missingAPIKey
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "Whisper model is not initialized."
        case .missingAPIKey:
            return "Please add your OpenAI API Key in Settings to use cloud transcription."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
