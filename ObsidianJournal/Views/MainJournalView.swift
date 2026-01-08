import SwiftUI

struct MainJournalView: View {
    @ObservedObject var vaultManager: VaultManager
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriber = TranscriberService()
    @State private var journalService: JournalService?

    @State private var transcriptionText: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // MARK: - Header
                VStack {
                    Text(Date(), style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Daily Journal")
                        .font(.title)
                        .fontWeight(.bold)
                }

                Spacer()

                // MARK: - Visualization / Status
                if audioRecorder.isRecording {
                    VStack {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 120))
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse.byLayer)

                        Text("Recording...")
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                } else if isProcessing {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Transcribing...")
                            .padding(.top)
                    }
                } else {
                    Button(action: {
                        audioRecorder.startRecording()
                    }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 120))
                            .foregroundStyle(.blue)
                            .shadow(radius: 10)
                    }
                }

                Spacer()

                // MARK: - Controls
                if audioRecorder.isRecording {
                    Button(action: {
                        finishRecording()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.primary)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset Vault") {
                        vaultManager.reset()
                    }
                }
            }
            .onAppear {
                self.journalService = JournalService(vaultManager: vaultManager)
            }
        }
    }

    func finishRecording() {
        audioRecorder.stopRecording()

        guard let url = audioRecorder.recordingURL else {
            errorMessage = "Recording failed"
            return
        }

        processRecording(url: url)
    }

    func processRecording(url: URL) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let text = try await transcriber.transcribe(audioURL: url)
                await MainActor.run {
                    self.transcriptionText = text
                }

                try await journalService?.saveEntry(text: text)

                await MainActor.run {
                    self.isProcessing = false
                    // Optional: Show success / haptic feedback
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}

#Preview {
    MainJournalView(vaultManager: VaultManager())
}
