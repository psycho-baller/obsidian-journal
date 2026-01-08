import Foundation
import Combine
import os

class DraftManager: ObservableObject {
    @Published var drafts: [Draft] = []
    @Published var currentDraft: Draft?

    private let draftsFileName = "drafts.json"

    // Computed properties for views
    var activeDrafts: [Draft] {
        drafts.filter { $0.status == .draft }
    }

    var archivedDrafts: [Draft] {
        drafts.filter { $0.status == .archived }
    }

    init() {
        loadDrafts()

        // Ensure there is at least one draft (the current active one) or create a new one
        if let lastEdited = activeDrafts.sorted(by: { $0.modifiedAt > $1.modifiedAt }).first {
            self.currentDraft = lastEdited
        } else {
            createNewDraft()
        }

        Logger.ui.debug("DraftManager initialized. Total count: \(self.drafts.count). Active: \(self.activeDrafts.count)")
    }

    func createNewDraft() {
        let newDraft = Draft()
        drafts.append(newDraft)
        currentDraft = newDraft
        saveDrafts()
        Logger.ui.info("Created new draft: \(newDraft.id)")
    }

    func updateCurrentDraft(content: String) {
        guard var draft = currentDraft else { return }
        draft.content = content
        draft.modifiedAt = Date()

        // Update local state
        currentDraft = draft

        // Update in array
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
        } else {
            drafts.append(draft)
        }

        saveDrafts()
    }

    func archiveDraft(_ draft: Draft) {
        guard let index = drafts.firstIndex(where: { $0.id == draft.id }) else { return }

        var archivedDraft = drafts[index]
        archivedDraft.status = .archived
        archivedDraft.modifiedAt = Date()

        drafts[index] = archivedDraft

        // If the archived draft was current, create a new one
        if currentDraft?.id == draft.id {
            createNewDraft()
        }

        saveDrafts()
        Logger.ui.info("Archived draft: \(draft.id)")
    }

    func restoreDraft(_ draft: Draft) {
        guard let index = drafts.firstIndex(where: { $0.id == draft.id }) else { return }

        var restoredDraft = drafts[index]
        restoredDraft.status = .draft
        restoredDraft.modifiedAt = Date()

        drafts[index] = restoredDraft
        saveDrafts()
        Logger.ui.info("Restored draft: \(draft.id)")
    }

    func deleteDraft(_ draft: Draft) {
        drafts.removeAll { $0.id == draft.id }
        // If we deleted the current draft, check if we have any other active drafts
        if currentDraft?.id == draft.id {
            if let nextDraft = activeDrafts.first {
                currentDraft = nextDraft
            } else {
                createNewDraft()
            }
        }
        saveDrafts()
        Logger.ui.info("Deleted draft: \(draft.id)")
    }

    func selectDraft(_ draft: Draft) {
        self.currentDraft = draft
        Logger.ui.debug("Selected draft: \(draft.id)")
    }

    // MARK: - Persistence

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveDrafts() {
        let url = getDocumentsDirectory().appendingPathComponent(draftsFileName)
        do {
            let data = try JSONEncoder().encode(drafts)
            try data.write(to: url)
        } catch {
            Logger.ui.error("Failed to save drafts: \(error.localizedDescription)")
        }
    }

    private func loadDrafts() {
        let url = getDocumentsDirectory().appendingPathComponent(draftsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            drafts = try JSONDecoder().decode([Draft].self, from: data)
            Logger.ui.info("Loaded \(self.drafts.count) drafts.")
        } catch {
            Logger.ui.error("Failed to load drafts: \(error.localizedDescription)")
        }
    }
}
