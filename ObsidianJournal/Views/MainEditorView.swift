import SwiftUI
import AVFoundation

struct MainEditorView: View {
    @StateObject private var draftManager = DraftManager()
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriberService = TranscriberService()
    @EnvironmentObject var journalService: JournalService
    @EnvironmentObject var vaultManager: VaultManager // Access to shared VaultManager

    // UI State
    @State private var showDrafts = false
    @State private var showArchive = false
    @State private var showSettings = false

    // Text Editor State
    @State private var cursorPosition: Int = 0
    @State private var isDictating = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.primary.colorInvert().ignoresSafeArea() // Background

                VStack(spacing: 0) {
                    // Editor Area
                    if let draft = draftManager.currentDraft {
                        CursorAwareTextEditor(
                            text: Binding(
                                get: { draft.content },
                                set: { draftManager.updateCurrentDraft(content: $0) }
                            ),
                            cursorPosition: $cursorPosition,
                            isEditable: !audioRecorder.isRecording
                        )
                        .padding(.horizontal)
                    } else {
                        // Fallback if no draft (shouldn't happen)
                        Text("No Draft Selected")
                            .foregroundColor(.secondary)
                    }
                }

                // Bottom Floating Bar
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        // Dictate / Stop Button
                        Button(action: toggleRecording) {
                            HStack {
                                Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.title2)
                                if audioRecorder.isRecording {
                                    Text("Stop")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(
                                Capsule()
                                    .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                                    .shadow(color: (audioRecorder.isRecording ? Color.red : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
                            )
                        }

                        // Submit Button (only if content exists)
                        if let content = draftManager.currentDraft?.content, !content.isEmpty {
                            Button(action: submitEntry) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.green)
                                    .background(Circle().fill(Color.white))
                                    .shadow(radius: 5)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(draftManager.currentDraft?.modifiedAt.formatted(date: .abbreviated, time: .shortened) ?? "Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDrafts.toggle() }) {
                        Image(systemName: "sidebar.left")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showArchive.toggle() }) {
                            Image(systemName: "archivebox")
                        }
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }

                // Keyboard Toolbar
                ToolbarItemGroup(placement: .keyboard) {
                     Spacer()

                     // Mic Button
                     Button(action: toggleRecording) {
                         HStack(spacing: 6) {
                             Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                 .foregroundColor(audioRecorder.isRecording ? .red : .blue)
                             Text(audioRecorder.isRecording ? "Stop" : "Dictate")
                                 .foregroundColor(audioRecorder.isRecording ? .red : .primary)
                         }
                         .padding(.horizontal, 12)
                         .padding(.vertical, 6)
                         .background(Material.thin)
                         .clipShape(Capsule())
                     }

                     Spacer()

                     // Submit Button
                     if let content = draftManager.currentDraft?.content, !content.isEmpty {
                         Button(action: submitEntry) {
                             HStack(spacing: 6) {
                                 Text("Submit")
                                 Image(systemName: "arrow.up.circle.fill")
                             }
                             .foregroundColor(.green)
                             .padding(.horizontal, 12)
                             .padding(.vertical, 6)
                             .background(Material.thin)
                             .clipShape(Capsule())
                         }
                     }
                }
            }
            .sheet(isPresented: $showDrafts) {
                DraftsListView(draftManager: draftManager, isPresented: $showDrafts)
            }
            .sheet(isPresented: $showArchive) {
                ArchiveListView(draftManager: draftManager, isPresented: $showArchive)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .onReceive(audioRecorder.$recordingURL) { url in
            // When recording stops and URL is set, trigger transcription
            if let url = url, !audioRecorder.isRecording {
                processTranscription(url: url)
            }
        }
        .onAppear {
            // Set cursor to end of existing draft so transcriptions append by default
            if let draft = draftManager.currentDraft {
                cursorPosition = draft.content.count
            }
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            isDictating = false
        } else {
            audioRecorder.startRecording()
            isDictating = true
        }
    }

    private func processTranscription(url: URL) {
        Task {
            do {
                let text = try await transcriberService.transcribe(audioURL: url)

                // Insert text at cursor position
                await MainActor.run {
                    guard let draft = draftManager.currentDraft else { return }
                    var newContent = draft.content

                    // Simple insertion logic
                    // Ensure we handle index correctly (Swift String indices are tricky)
                    if cursorPosition > newContent.count {
                        cursorPosition = newContent.count
                    }
                    let index = newContent.index(newContent.startIndex, offsetBy: cursorPosition)

                    // Add space if needed
                    let textToInsert = (cursorPosition > 0 ? " " : "") + text

                    newContent.insert(contentsOf: textToInsert, at: index)
                    draftManager.updateCurrentDraft(content: newContent)

                    // Move cursor
                    cursorPosition += textToInsert.count
                }
            } catch {
                print("Transcription error: \(error)")
            }
        }
    }

    private func submitEntry() {
        guard let draft = draftManager.currentDraft else { return }

        Task {
            do {
                let llmService = LLMService()
                let date = draft.createdAt.journalDate

                // Step 1: Read existing daily note or get default template
                let existingNote = try journalService.readDailyNote(for: date) ?? journalService.getDefaultTemplate(for: date)

                // Step 2: Call AI to extract structured updates from transcript
                let populationResponse = try await llmService.populateTemplate(
                    transcript: draft.content,
                    existingNote: existingNote,
                    date: date
                )

                // Step 3: Apply updates to the note
                try journalService.applyTemplateUpdates(
                    populationResponse.updates,
                    to: existingNote,
                    for: date
                )

                // Step 4: Archive the draft
                await MainActor.run {
                    draftManager.archiveDraft(draft)
                }
            } catch {
                print("Submission failed: \(error)")
                // TODO: Show error alert
            }
        }
    }
}
