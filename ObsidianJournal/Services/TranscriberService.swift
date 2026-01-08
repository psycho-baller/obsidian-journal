import Foundation
import os
import WhisperKit

protocol TranscriberServiceProtocol {
    func transcribe(audioURL: URL) async throws -> String
}

class TranscriberService: ObservableObject, TranscriberServiceProtocol {
    @Published var isTranscribing = false
    @Published var modelLoadingState: ModelLoadingState = .notLoaded
    @Published var progress: Double = 0.0

    private var whisperPipe: WhisperKit?
    private let modelName = "base.en" // "base.en" (optimized) or "small.en" depending on device

    enum ModelLoadingState: Equatable {
        case notLoaded
        case loading
        case loaded
        case error(String)
    }

    init() {
        Task {
            await loadModel()
        }
    }

    @MainActor
    func loadModel() async {
        guard modelLoadingState != .loading && modelLoadingState != .loaded else { return }

        modelLoadingState = .loading
        Logger.transcription.info("Initializing WhisperKit with model: \(self.modelName)")

        do {
            // WhisperKit will automatically download (if needed) and load the model
            // optimizing for the Neural Engine where possible.
            whisperPipe = try await WhisperKit(model: modelName)
            modelLoadingState = .loaded
            Logger.transcription.notice("WhisperKit initialized successfully.")
        } catch {
            Logger.transcription.error("Failed to load WhisperKit: \(error.localizedDescription)")
            modelLoadingState = .error(error.localizedDescription)
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let pipe = whisperPipe else {
            if modelLoadingState == .notLoaded || modelLoadingState == .loading.self {
                 Logger.transcription.warning("Transcription requested but model not ready. Waiting...")
                 await loadModel()
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
}

enum TranscriberError: Error, LocalizedError {
    case modelNotInitialized

    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "Whisper model is not initialized."
        }
    }
}
